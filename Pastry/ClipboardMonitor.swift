import Foundation

/// Watches the pasteboard and reports newly copied text as a `Clip`.
///
/// There is no notification for the system pasteboard, so this polls
/// `changeCount` on a loop. The loop is a `Task` rather than a `Timer`: main
/// actor work is dispatched to the main queue, which keeps draining while a
/// menu is tracking, so a clip copied with the status menu open is still seen.
/// A `Timer` would need `.common` run loop modes to manage that, and cannot be
/// torn down from the nonisolated `deinit` of a main-actor class.
@MainActor
final class ClipboardMonitor {
    /// Marker a source application sets on a clip it considers secret.
    /// Honoured unconditionally — see the design spec's privacy section.
    static let concealedType = "org.nspasteboard.ConcealedType"

    private let source: ClipboardSource
    private let frontmostApp: () -> SourceApp?
    private let now: () -> Date
    private let interval: Duration
    private let onCapture: (Clip) -> Void
    private var lastChangeCount: Int
    /// A change whose text could not be read yet, awaiting one more attempt.
    private var retryingChangeCount: Int?
    private var pollTask: Task<Void, Never>?

    init(
        source: ClipboardSource,
        frontmostApp: @escaping () -> SourceApp? = { SystemFrontmostApp.current() },
        now: @escaping () -> Date = Date.init,
        interval: Duration = .milliseconds(500),
        onCapture: @escaping (Clip) -> Void
    ) {
        self.source = source
        self.frontmostApp = frontmostApp
        self.now = now
        self.interval = interval
        self.onCapture = onCapture
        self.lastChangeCount = source.changeCount
    }

    func start() {
        guard pollTask == nil else { return }
        let interval = interval
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                // Tolerance lets the kernel coalesce these wakeups with others;
                // this process is otherwise idle all day. A cancelled sleep
                // ends the loop here: swallowing the error would let one more
                // poll run after stop() returned.
                do {
                    try await Task.sleep(for: interval, tolerance: .milliseconds(100))
                } catch {
                    return
                }
                // A sleep that finished before stop() was called cannot be
                // made to throw retroactively, so check again here: otherwise
                // one poll still runs after stop() returned.
                if Task.isCancelled { return }
                // Dropped without stop() being called: end the loop rather
                // than poll a monitor nobody owns any more.
                guard let self else { return }
                await self.poll()
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Puts text on the pasteboard without recording it again.
    ///
    /// One call rather than "write, then remember to suppress": the change
    /// count comes back from the write itself, so a copy the user makes in
    /// between cannot be swallowed, and no caller can forget the second step.
    func write(_ text: String) {
        lastChangeCount = source.write(text)
    }

    func poll() async {
        let changeCount = source.changeCount
        let seenBeforeReading = lastChangeCount
        guard changeCount != seenBeforeReading else { return }

        if source.hasType(Self.concealedType) {
            lastChangeCount = changeCount
            retryingChangeCount = nil
            return
        }

        let read = await source.string()

        // Reading suspends, and write(_:) can land while it does — choosing a
        // menu row does exactly that. Its change count is the current one now,
        // so writing this poll's older count back would un-suppress the paste
        // and capture Pastry's own clip on the next cycle.
        guard lastChangeCount == seenBeforeReading else { return }

        guard let text = read else {
            // A writer bumps the change count with clearContents() before it
            // supplies the data, so a poll landing in that gap sees no text.
            // Give it one more cycle before writing the change off, rather
            // than losing the clip permanently — but only one, so a clip that
            // genuinely holds no text is not re-read on every poll for as
            // long as it sits on the pasteboard.
            if retryingChangeCount == changeCount {
                lastChangeCount = changeCount
                retryingChangeCount = nil
            } else {
                retryingChangeCount = changeCount
            }
            return
        }

        lastChangeCount = changeCount
        retryingChangeCount = nil
        guard !text.isEmpty else { return }

        onCapture(Clip(text: text, source: frontmostApp(), date: now()))
    }
}

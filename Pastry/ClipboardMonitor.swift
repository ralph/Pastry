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
                // Dropped without stop() being called: end the loop rather
                // than poll a monitor nobody owns any more.
                guard let self else { return }
                self.poll()
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

    func poll() {
        let changeCount = source.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        guard !source.hasType(Self.concealedType) else { return }
        guard let text = source.string(), !text.isEmpty else { return }

        onCapture(Clip(text: text, source: frontmostApp(), date: now()))
    }
}

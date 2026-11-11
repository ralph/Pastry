import Foundation

/// Watches the pasteboard and reports newly copied text.
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
    private let interval: Duration
    private let onCapture: (String) -> Void
    private var lastChangeCount: Int
    private var pollTask: Task<Void, Never>?

    init(
        source: ClipboardSource,
        interval: Duration = .milliseconds(500),
        onCapture: @escaping (String) -> Void
    ) {
        self.source = source
        self.interval = interval
        self.onCapture = onCapture
        self.lastChangeCount = source.changeCount
    }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let interval = self?.interval else { return }
                try? await Task.sleep(for: interval)
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

    /// Treats whatever is on the pasteboard right now as already seen. Called
    /// straight after Pastry writes a clip, so pasting does not re-record it.
    func ignoreCurrentContents() {
        lastChangeCount = source.changeCount
    }

    func poll() {
        let changeCount = source.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        guard !source.types.contains(Self.concealedType) else { return }
        guard let text = source.string(), !text.isEmpty else { return }

        onCapture(text)
    }
}

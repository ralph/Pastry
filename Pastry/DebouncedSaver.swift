import Foundation

/// Collapses a burst of changes into one write.
///
/// Every capture is a change, and so is choosing a clip, which moves it to the
/// top. Writing the whole history for each would mean a file write per event,
/// so the last change within the delay is the one that gets written.
@MainActor
final class DebouncedSaver {
    private let delay: Duration
    private let save: ([Clip]) -> Void
    private var pending: [Clip]?
    private var task: Task<Void, Never>?

    init(delay: Duration = .seconds(2), save: @escaping ([Clip]) -> Void) {
        self.delay = delay
        self.save = save
    }

    func schedule(_ clips: [Clip]) {
        pending = clips
        task?.cancel()
        let delay = delay
        task = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                // Superseded by a later change, which owns the write now.
                return
            }
            self?.flush()
        }
    }

    /// Writes a pending save immediately. Termination calls this, where there
    /// is no later moment to wait for.
    func flush() {
        task?.cancel()
        task = nil
        guard let clips = pending else { return }
        pending = nil
        save(clips)
    }
}

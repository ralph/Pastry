import Foundation

/// Collapses a burst of changes into one write.
///
/// Every capture is a change, and so is choosing a clip, which moves it to the
/// top. Writing the whole history for each would mean a file write per event.
@MainActor
final class DebouncedSaver {
    private let delay: Duration
    private let maxDelay: Duration
    private let save: @Sendable ([Clip]) -> Bool

    private var pending: [Clip]?
    /// When the oldest unwritten change arrived, so a steady stream of changes
    /// cannot defer the write indefinitely.
    private var pendingSince: ContinuousClock.Instant?
    private var task: Task<Void, Never>?

    /// - Parameters:
    ///   - delay: how long after the last change to write.
    ///   - maxDelay: the longest anything may stay unwritten. Without it, a
    ///     user copying and pasting faster than `delay` would reset the timer
    ///     forever and never write at all — a crash would then cost the whole
    ///     session rather than a couple of seconds, which is the one thing
    ///     this feature exists to prevent.
    init(
        delay: Duration = .seconds(2),
        maxDelay: Duration = .seconds(10),
        save: @escaping @Sendable ([Clip]) -> Bool
    ) {
        self.delay = delay
        self.maxDelay = maxDelay
        self.save = save
    }

    func schedule(_ clips: [Clip]) {
        let now = ContinuousClock.now
        pending = clips
        if pendingSince == nil { pendingSince = now }

        task?.cancel()
        let deadline = min(
            now.advanced(by: delay),
            (pendingSince ?? now).advanced(by: maxDelay)
        )
        task = Task { [weak self] in
            do {
                try await Task.sleep(until: deadline, clock: .continuous)
            } catch {
                // Superseded by a later change, which owns the write now.
                return
            }
            await self?.writePending()
        }
    }

    /// Writes any pending change immediately, on this thread.
    ///
    /// For termination, where there is no later moment to wait for, and for
    /// changes that must not sit in a buffer — clearing the history is meant
    /// to take effect now, not in two seconds.
    func flush() {
        task?.cancel()
        task = nil
        guard let clips = takePending() else { return }
        if !save(clips) { restorePending(clips) }
    }

    private func writePending() async {
        task = nil
        guard let clips = takePending() else { return }

        // Encoding and writing the whole history can mean megabytes; doing it
        // on the main actor would stutter the menu bar every couple of
        // seconds. Termination still writes synchronously, above.
        let save = save
        let written = await Task.detached(priority: .utility) { save(clips) }.value
        if !written { restorePending(clips) }
    }

    private func takePending() -> [Clip]? {
        guard let clips = pending else { return nil }
        pending = nil
        pendingSince = nil
        return clips
    }

    /// A failed write must not be reported as done: keep the change so the
    /// next one, or termination, tries again.
    private func restorePending(_ clips: [Clip]) {
        guard pending == nil else { return }  // a newer change already supersedes it
        pending = clips
        pendingSince = ContinuousClock.now
    }
}

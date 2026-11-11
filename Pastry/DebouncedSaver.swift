import Foundation

/// Collapses a burst of changes into one write.
///
/// Every capture is a change, and so is choosing a clip, which moves it to the
/// top. Writing the whole history for each would mean a file write per event.
///
/// Writes happen on the main actor, deliberately. Moving them to a detached
/// task to avoid encoding megabytes on the main thread introduced three
/// separate ways to lose data: a slow write finishing after a later one and
/// resurrecting clips the user had deleted, termination not waiting for a
/// write already in flight, and a stale failed write restoring itself over
/// newer clips. Doing the work in order on one actor removes all three by
/// construction. The cost is a possible hitch when the history is unusually
/// large, which is the better trade for the user's clipboard history.
@MainActor
final class DebouncedSaver {
    private let delay: Duration
    private let maxDelay: Duration
    private let save: ([Clip]) -> Bool

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
        save: @escaping ([Clip]) -> Bool
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
            self?.flush()
        }
    }

    /// Writes any pending change immediately.
    ///
    /// For termination, where there is no later moment to wait for, and for
    /// changes that must not sit in a buffer — clearing the history is meant
    /// to take effect now, not in two seconds.
    func flush() {
        task?.cancel()
        task = nil
        guard let clips = pending else { return }
        pending = nil
        pendingSince = nil

        // A failed write must not be reported as done: keep the change so the
        // next one, or termination, tries again.
        if !save(clips) {
            pending = clips
            pendingSince = ContinuousClock.now
        }
    }
}

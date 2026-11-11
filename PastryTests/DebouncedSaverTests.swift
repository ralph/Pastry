import Foundation
import Testing
@testable import Pastry

@Suite("DebouncedSaver")
@MainActor
struct DebouncedSaverTests {
    /// Counts writes and can refuse them, from any isolation.
    final class Writes: @unchecked Sendable {
        private let lock = NSLock()
        private var _saved: [[String]] = []
        private var _succeed = true

        var saved: [[String]] { lock.withLock { _saved } }
        var count: Int { lock.withLock { _saved.count } }
        func refuseWrites() { lock.withLock { _succeed = false } }
        func allowWrites() { lock.withLock { _succeed = true } }

        func record(_ clips: [Clip]) -> Bool {
            lock.withLock {
                guard _succeed else { return false }
                _saved.append(clips.map(\.text))
                return true
            }
        }
    }

    private func makeSaver(
        delay: Duration = .zero,
        maxDelay: Duration = .seconds(10),
        writes: Writes
    ) -> DebouncedSaver {
        DebouncedSaver(delay: delay, maxDelay: maxDelay) { writes.record($0) }
    }

    /// The write happens on a detached task, so settle rather than sleep for a
    /// fixed span — a fixed margin is what makes a suite flaky under load.
    private func settle() async {
        for _ in 0..<200 {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(1))
        }
    }

    @Test("does not write synchronously")
    func doesNotWriteSynchronously() {
        let writes = Writes()
        makeSaver(writes: writes).schedule([Clip.fixture("a")])
        #expect(writes.count == 0)
    }

    @Test("writes once the delay has passed")
    func writesAfterTheDelay() async {
        let writes = Writes()
        let saver = makeSaver(writes: writes)
        saver.schedule([Clip.fixture("a")])
        await settle()
        #expect(writes.saved == [["a"]])
    }

    /// Copying several things in quick succession should cost one write.
    @Test("collapses a burst into a single write of the latest clips")
    func collapsesABurst() async {
        let writes = Writes()
        let saver = makeSaver(delay: .milliseconds(80), writes: writes)

        saver.schedule([Clip.fixture("a")])
        saver.schedule([Clip.fixture("b")])
        saver.schedule([Clip.fixture("c")])
        await settle()

        #expect(writes.saved == [["c"]])
    }

    /// Without a cap, changes arriving faster than the delay reset the timer
    /// forever and nothing is ever written — a crash would then cost the whole
    /// session, which is the one thing this is meant to prevent.
    @Test("writes anyway once the maximum wait is reached")
    func writesDespiteContinuousChanges() async {
        let writes = Writes()
        let saver = makeSaver(delay: .seconds(60), maxDelay: .milliseconds(50), writes: writes)

        // Each of these would reset a plain debounce.
        for index in 0..<5 {
            saver.schedule([Clip.fixture("change \(index)")])
            try? await Task.sleep(for: .milliseconds(15))
        }
        await settle()

        #expect(writes.count >= 1)
        #expect(writes.saved.last == ["change 4"])
    }

    @Test("flush writes a pending change at once")
    func flushWritesPending() {
        let writes = Writes()
        let saver = makeSaver(delay: .seconds(60), writes: writes)
        saver.schedule([Clip.fixture("a")])
        saver.flush()
        #expect(writes.saved == [["a"]])
    }

    @Test("flush does not write again once there is nothing pending")
    func flushIsIdempotent() {
        let writes = Writes()
        let saver = makeSaver(delay: .seconds(60), writes: writes)
        saver.schedule([Clip.fixture("a")])
        saver.flush()
        saver.flush()
        #expect(writes.count == 1)
    }

    @Test("flush with nothing pending writes nothing")
    func flushWithoutPending() {
        let writes = Writes()
        makeSaver(writes: writes).flush()
        #expect(writes.count == 0)
    }

    @Test("a change after a flush still writes")
    func scheduleAfterFlush() {
        let writes = Writes()
        let saver = makeSaver(delay: .seconds(60), writes: writes)
        saver.schedule([Clip.fixture("a")])
        saver.flush()
        saver.schedule([Clip.fixture("b")])
        saver.flush()
        #expect(writes.saved == [["a"], ["b"]])
    }

    /// A write that failed must not be reported as done, or the change is
    /// lost with nothing but a log line.
    @Test("keeps a change whose write failed")
    func keepsAFailedWrite() {
        let writes = Writes()
        let saver = makeSaver(delay: .seconds(60), writes: writes)
        writes.refuseWrites()

        saver.schedule([Clip.fixture("a")])
        saver.flush()
        #expect(writes.count == 0)

        writes.allowWrites()
        saver.flush()
        #expect(writes.saved == [["a"]])
    }

    @Test("a failed write is superseded by a newer change rather than resurrected")
    func failedWriteDoesNotOverrideNewerClips() {
        let writes = Writes()
        let saver = makeSaver(delay: .seconds(60), writes: writes)
        writes.refuseWrites()
        saver.schedule([Clip.fixture("old")])
        saver.flush()

        writes.allowWrites()
        saver.schedule([Clip.fixture("new")])
        saver.flush()

        #expect(writes.saved == [["new"]])
    }
}

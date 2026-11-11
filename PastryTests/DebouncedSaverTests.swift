import Foundation
import Testing
@testable import Pastry

@Suite("DebouncedSaver")
@MainActor
struct DebouncedSaverTests {
    final class Recorder { var saves: [[String]] = [] }

    private func makeSaver(
        delay: Duration = .milliseconds(50),
        recorder: Recorder
    ) -> DebouncedSaver {
        DebouncedSaver(delay: delay) { clips in
            recorder.saves.append(clips.map(\.text))
        }
    }

    @Test("does not save straight away")
    func doesNotSaveImmediately() {
        let recorder = Recorder()
        let saver = makeSaver(recorder: recorder)
        saver.schedule([Clip.fixture("a")])
        #expect(recorder.saves.isEmpty)
    }

    @Test("saves once the delay has passed")
    func savesAfterTheDelay() async throws {
        let recorder = Recorder()
        let saver = makeSaver(recorder: recorder)
        saver.schedule([Clip.fixture("a")])
        try await Task.sleep(for: .milliseconds(300))
        #expect(recorder.saves == [["a"]])
    }

    /// Copying several things in quick succession should cost one write, not
    /// one per clip.
    @Test("collapses a burst into a single save of the latest clips")
    func collapsesABurst() async throws {
        let recorder = Recorder()
        let saver = makeSaver(recorder: recorder)

        saver.schedule([Clip.fixture("a")])
        saver.schedule([Clip.fixture("b")])
        saver.schedule([Clip.fixture("c")])
        try await Task.sleep(for: .milliseconds(300))

        #expect(recorder.saves == [["c"]])
    }

    @Test("flush writes a pending save at once")
    func flushWritesPending() {
        let recorder = Recorder()
        let saver = makeSaver(delay: .seconds(60), recorder: recorder)
        saver.schedule([Clip.fixture("a")])
        saver.flush()
        #expect(recorder.saves == [["a"]])
    }

    /// Termination calls flush; a second write would mean the pending state
    /// leaked rather than being consumed.
    @Test("flush does not write again once there is nothing pending")
    func flushIsIdempotent() {
        let recorder = Recorder()
        let saver = makeSaver(delay: .seconds(60), recorder: recorder)
        saver.schedule([Clip.fixture("a")])
        saver.flush()
        saver.flush()
        #expect(recorder.saves.count == 1)
    }

    @Test("flush with nothing pending writes nothing")
    func flushWithoutPending() {
        let recorder = Recorder()
        makeSaver(recorder: recorder).flush()
        #expect(recorder.saves.isEmpty)
    }

    @Test("a save after a flush still works")
    func scheduleAfterFlush() {
        let recorder = Recorder()
        let saver = makeSaver(delay: .seconds(60), recorder: recorder)
        saver.schedule([Clip.fixture("a")])
        saver.flush()
        saver.schedule([Clip.fixture("b")])
        saver.flush()
        #expect(recorder.saves == [["a"], ["b"]])
    }

    /// A pending write must not be lost when a later change supersedes it:
    /// the later clips are what gets written, not nothing.
    @Test("a superseded save does not write the earlier clips")
    func supersededSaveIsDiscarded() async throws {
        let recorder = Recorder()
        let saver = makeSaver(recorder: recorder)
        saver.schedule([Clip.fixture("first")])
        try await Task.sleep(for: .milliseconds(10))
        saver.schedule([Clip.fixture("second")])
        try await Task.sleep(for: .milliseconds(300))
        #expect(recorder.saves == [["second"]])
    }
}

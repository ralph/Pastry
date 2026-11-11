import Foundation
import Testing
@testable import Pastry

@Suite("Paster")
@MainActor
struct PasterTests {
    /// Records what the paster did to the system, in order.
    final class Recorder {
        var steps: [String] = []
        var written: [String] = []
        var trustRequests = 0
    }

    private func makePaster(
        isTrusted: @escaping () -> Bool,
        recorder: Recorder,
        keystrokeSucceeds: Bool = true,
        delay: Duration = .zero
    ) -> Paster {
        Paster(
            write: { text in
                recorder.steps.append("write")
                recorder.written.append(text)
            },
            yieldFocus: { recorder.steps.append("yieldFocus") },
            sendPaste: {
                recorder.steps.append("sendPaste")
                return keystrokeSucceeds
            },
            isTrusted: isTrusted,
            requestTrust: { recorder.trustRequests += 1 },
            delay: delay
        )
    }

    @Test("writes, yields focus, then sends the keystroke, in that order")
    func pastesInOrder() async {
        let recorder = Recorder()
        let paster = makePaster(isTrusted: { true }, recorder: recorder)

        let outcome = await paster.paste("hello")

        #expect(outcome == .pasted)
        #expect(recorder.steps == ["write", "yieldFocus", "sendPaste"])
        #expect(recorder.written == ["hello"])
    }

    @Test("does not ask for permission it already has")
    func doesNotPromptWhenTrusted() async {
        let recorder = Recorder()
        let paster = makePaster(isTrusted: { true }, recorder: recorder)
        await paster.paste("hello")
        #expect(recorder.trustRequests == 0)
    }

    /// The useful half still works: the clip is on the pasteboard, so ⌘V by
    /// hand pastes it. Doing nothing at all would be worse.
    @Test("still copies the clip when permission is missing")
    func copiesWithoutPermission() async {
        let recorder = Recorder()
        let paster = makePaster(isTrusted: { false }, recorder: recorder)

        let outcome = await paster.paste("hello")

        #expect(outcome == .copiedWithoutPermission)
        #expect(recorder.written == ["hello"])
    }

    @Test("sends no keystroke without permission")
    func sendsNoKeystrokeWithoutPermission() async {
        let recorder = Recorder()
        let paster = makePaster(isTrusted: { false }, recorder: recorder)
        await paster.paste("hello")
        #expect(!recorder.steps.contains("sendPaste"))
        #expect(!recorder.steps.contains("yieldFocus"))
    }

    @Test("asks for permission when it is missing")
    func asksForPermission() async {
        let recorder = Recorder()
        let paster = makePaster(isTrusted: { false }, recorder: recorder)
        await paster.paste("hello")
        #expect(recorder.trustRequests == 1)
    }

    /// The system dialog is disruptive; one refusal should not mean one dialog
    /// per clip for the rest of the session.
    @Test("asks for permission only once per launch")
    func asksOnlyOnce() async {
        let recorder = Recorder()
        let paster = makePaster(isTrusted: { false }, recorder: recorder)
        await paster.paste("one")
        await paster.paste("two")
        await paster.paste("three")
        #expect(recorder.trustRequests == 1)
    }

    /// A failed keystroke must not be reported as a paste: the user would see
    /// nothing happen and the log would claim success.
    @Test("reports a keystroke the event stream refused")
    func reportsAFailedKeystroke() async {
        let recorder = Recorder()
        let paster = makePaster(isTrusted: { true }, recorder: recorder, keystrokeSucceeds: false)
        #expect(await paster.paste("hello") == .keystrokeFailed)
    }

    /// Two pastes across the wait would interleave — the first would resume
    /// after the second replaced the pasteboard and type the second's clip.
    @Test("refuses a second paste while one is in flight")
    func refusesOverlappingPaste() async {
        let recorder = Recorder()
        let paster = makePaster(
            isTrusted: { true },
            recorder: recorder,
            delay: .milliseconds(50)
        )

        async let first = paster.paste("A")

        // Task.yield() alone does not guarantee the first paste has started,
        // which would make this test fail against correct code. Wait for the
        // first paste to announce that it holds the guard, bounded so a
        // regression fails rather than hangs.
        var spins = 0
        while !recorder.steps.contains("yieldFocus"), spins < 10_000 {
            await Task.yield()
            spins += 1
        }
        #expect(recorder.steps.contains("yieldFocus"), "the first paste never reached its wait")

        let second = await paster.paste("B")
        let firstOutcome = await first

        #expect(firstOutcome == .pasted)
        #expect(second == .alreadyPasting)
        // B never even reached the pasteboard.
        #expect(recorder.written == ["A"])
    }

    /// Permission can be granted in System Settings while Pastry runs, and it
    /// must start working without a relaunch.
    @Test("pastes once permission is granted mid-session")
    func noticesPermissionGrantedLater() async {
        let recorder = Recorder()
        nonisolated(unsafe) var trusted = false
        let paster = makePaster(isTrusted: { trusted }, recorder: recorder)

        #expect(await paster.paste("before") == .copiedWithoutPermission)
        trusted = true
        #expect(await paster.paste("after") == .pasted)
        #expect(recorder.steps.contains("sendPaste"))
    }
}

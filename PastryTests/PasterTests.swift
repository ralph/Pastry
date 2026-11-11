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

    private func makePaster(trusted: Bool, recorder: Recorder) -> Paster {
        Paster(
            write: { text in
                recorder.steps.append("write")
                recorder.written.append(text)
            },
            yieldFocus: { recorder.steps.append("yieldFocus") },
            sendPaste: { recorder.steps.append("sendPaste") },
            isTrusted: { trusted },
            requestTrust: { recorder.trustRequests += 1 },
            delay: .zero
        )
    }

    @Test("writes, yields focus, then sends the keystroke, in that order")
    func pastesInOrder() async {
        let recorder = Recorder()
        let paster = makePaster(trusted: true, recorder: recorder)

        let outcome = await paster.paste("hello")

        #expect(outcome == .pasted)
        #expect(recorder.steps == ["write", "yieldFocus", "sendPaste"])
        #expect(recorder.written == ["hello"])
    }

    @Test("does not ask for permission it already has")
    func doesNotPromptWhenTrusted() async {
        let recorder = Recorder()
        let paster = makePaster(trusted: true, recorder: recorder)
        await paster.paste("hello")
        #expect(recorder.trustRequests == 0)
    }

    /// The useful half still works: the clip is on the pasteboard, so ⌘V by
    /// hand pastes it. Doing nothing at all would be worse.
    @Test("still copies the clip when permission is missing")
    func copiesWithoutPermission() async {
        let recorder = Recorder()
        let paster = makePaster(trusted: false, recorder: recorder)

        let outcome = await paster.paste("hello")

        #expect(outcome == .copiedWithoutPermission)
        #expect(recorder.written == ["hello"])
    }

    @Test("sends no keystroke without permission")
    func sendsNoKeystrokeWithoutPermission() async {
        let recorder = Recorder()
        let paster = makePaster(trusted: false, recorder: recorder)
        await paster.paste("hello")
        #expect(!recorder.steps.contains("sendPaste"))
        #expect(!recorder.steps.contains("yieldFocus"))
    }

    @Test("asks for permission when it is missing")
    func asksForPermission() async {
        let recorder = Recorder()
        let paster = makePaster(trusted: false, recorder: recorder)
        await paster.paste("hello")
        #expect(recorder.trustRequests == 1)
    }

    /// The system dialog is disruptive; one refusal should not mean one dialog
    /// per clip for the rest of the session.
    @Test("asks for permission only once per launch")
    func asksOnlyOnce() async {
        let recorder = Recorder()
        let paster = makePaster(trusted: false, recorder: recorder)
        await paster.paste("one")
        await paster.paste("two")
        await paster.paste("three")
        #expect(recorder.trustRequests == 1)
    }

    /// Permission can be granted in System Settings while Pastry runs, and it
    /// must start working without a relaunch.
    @Test("pastes once permission is granted mid-session")
    func noticesPermissionGrantedLater() async {
        let recorder = Recorder()
        var trusted = false
        let paster = Paster(
            write: { recorder.written.append($0) },
            yieldFocus: { recorder.steps.append("yieldFocus") },
            sendPaste: { recorder.steps.append("sendPaste") },
            isTrusted: { trusted },
            requestTrust: { recorder.trustRequests += 1 },
            delay: .zero
        )

        #expect(await paster.paste("before") == .copiedWithoutPermission)
        trusted = true
        #expect(await paster.paste("after") == .pasted)
        #expect(recorder.steps.contains("sendPaste"))
    }
}

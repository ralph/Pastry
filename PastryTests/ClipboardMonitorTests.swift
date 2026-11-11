import Foundation
import Testing
@testable import Pastry

/// A pasteboard whose contents the test sets directly.
@MainActor
private final class FakeClipboard: ClipboardSource {
    var changeCount = 0
    private var contents: String?
    private var presentTypes: Set<String> = ["public.utf8-plain-text"]

    func hasType(_ type: String) -> Bool { presentTypes.contains(type) }

    func string() -> String? { contents }

    @discardableResult
    func write(_ text: String) -> Int {
        contents = text
        presentTypes = ["public.utf8-plain-text"]
        changeCount += 1
        return changeCount
    }

    /// Mimics another application copying: new contents and a bumped count.
    func copy(_ text: String?, types: Set<String> = ["public.utf8-plain-text"]) {
        contents = text
        presentTypes = types
        changeCount += 1
    }
}

@Suite("ClipboardMonitor")
@MainActor
struct ClipboardMonitorTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeMonitor(
        app: SourceApp? = SourceApp(name: "Safari", bundleURL: nil),
        onCapture: @escaping (Clip) -> Void
    ) -> (FakeClipboard, ClipboardMonitor) {
        let clipboard = FakeClipboard()
        let monitor = ClipboardMonitor(
            source: clipboard,
            frontmostApp: { app },
            now: { Date(timeIntervalSince1970: 1_700_000_000) },
            onCapture: onCapture
        )
        return (clipboard, monitor)
    }

    @Test("captures nothing when the pasteboard has not changed")
    func noChangeNoCapture() {
        var captured: [Clip] = []
        let (_, monitor) = makeMonitor { captured.append($0) }
        monitor.poll()
        monitor.poll()
        #expect(captured.isEmpty)
    }

    @Test("captures newly copied text")
    func capturesNewText() {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor { captured.append($0) }
        clipboard.copy("hello")
        monitor.poll()
        #expect(captured.map(\.text) == ["hello"])
    }

    @Test("stamps the captured clip with the frontmost app and the current time")
    func stampsSourceAndTime() {
        var captured: [Clip] = []
        let url = URL(fileURLWithPath: "/Applications/Safari.app")
        let (clipboard, monitor) = makeMonitor(
            app: SourceApp(name: "Safari", bundleURL: url)
        ) { captured.append($0) }
        clipboard.copy("hello")
        monitor.poll()
        #expect(captured.first?.appName == "Safari")
        #expect(captured.first?.appBundleURL == url)
        #expect(captured.first?.date == epoch)
    }

    @Test("captures even when the frontmost app cannot be identified")
    func capturesWithoutAnIdentifiableApp() {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor(app: nil) { captured.append($0) }
        clipboard.copy("hello")
        monitor.poll()
        #expect(captured.map(\.text) == ["hello"])
        #expect(captured.first?.appName == nil)
    }

    @Test("captures one copy only once however often it polls")
    func capturesEachChangeOnce() {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor { captured.append($0) }
        clipboard.copy("hello")
        monitor.poll()
        monitor.poll()
        monitor.poll()
        #expect(captured.map(\.text) == ["hello"])
    }

    @Test("skips a clip the source marked concealed")
    func skipsConcealedClip() {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor { captured.append($0) }
        clipboard.copy("hunter2", types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"])
        monitor.poll()
        #expect(captured.isEmpty)
    }

    @Test("keeps working after a concealed clip")
    func recoversAfterConcealedClip() {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor { captured.append($0) }
        clipboard.copy("hunter2", types: ["org.nspasteboard.ConcealedType"])
        monitor.poll()
        clipboard.copy("ordinary")
        monitor.poll()
        #expect(captured.map(\.text) == ["ordinary"])
    }

    @Test("skips a change carrying no text")
    func skipsNonText() {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor { captured.append($0) }
        clipboard.copy(nil, types: ["public.png"])
        monitor.poll()
        #expect(captured.isEmpty)
    }

    @Test("skips empty text")
    func skipsEmptyText() {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor { captured.append($0) }
        clipboard.copy("")
        monitor.poll()
        #expect(captured.isEmpty)
    }

    @Test("does not record the clip it wrote itself")
    func ignoresOwnWrite() {
        var captured: [Clip] = []
        let (_, monitor) = makeMonitor { captured.append($0) }
        monitor.write("pasted by Pastry")
        monitor.poll()
        #expect(captured.isEmpty)
    }

    @Test("captures the next real copy after one of its own writes")
    func capturesAfterOwnWrite() {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor { captured.append($0) }
        monitor.write("pasted by Pastry")
        monitor.poll()
        clipboard.copy("typed by the user")
        monitor.poll()
        #expect(captured.map(\.text) == ["typed by the user"])
    }

    /// The old two-step contract — write, then suppress — could swallow a copy
    /// the user made in between. Writing and suppressing are now one call.
    @Test("a copy racing its own write is still captured")
    func doesNotSwallowACopyRacingTheWrite() {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor { captured.append($0) }
        monitor.write("pasted by Pastry")
        clipboard.copy("user copied this a moment later")
        monitor.poll()
        #expect(captured.map(\.text) == ["user copied this a moment later"])
    }
}

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

    /// When set, the next read fails, mimicking a writer that has bumped the
    /// change count but not yet supplied its data.
    var failNextRead = false

    /// How many times the monitor asked for the text.
    private(set) var readCount = 0

    func string() async -> String? {
        readCount += 1
        if failNextRead {
            failNextRead = false
            return nil
        }
        return contents
    }

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
    func noChangeNoCapture() async {
        var captured: [Clip] = []
        let (_, monitor) = makeMonitor { captured.append($0) }
        await monitor.poll()
        await monitor.poll()
        #expect(captured.isEmpty)
    }

    @Test("captures newly copied text")
    func capturesNewText() async {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor { captured.append($0) }
        clipboard.copy("hello")
        await monitor.poll()
        #expect(captured.map(\.text) == ["hello"])
    }

    @Test("stamps the captured clip with the frontmost app and the current time")
    func stampsSourceAndTime() async {
        var captured: [Clip] = []
        let url = URL(fileURLWithPath: "/Applications/Safari.app")
        let (clipboard, monitor) = makeMonitor(
            app: SourceApp(name: "Safari", bundleURL: url)
        ) { captured.append($0) }
        clipboard.copy("hello")
        await monitor.poll()
        #expect(captured.first?.appName == "Safari")
        #expect(captured.first?.appBundleURL == url)
        #expect(captured.first?.date == epoch)
    }

    @Test("captures even when the frontmost app cannot be identified")
    func capturesWithoutAnIdentifiableApp() async {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor(app: nil) { captured.append($0) }
        clipboard.copy("hello")
        await monitor.poll()
        #expect(captured.map(\.text) == ["hello"])
        #expect(captured.first?.appName == nil)
    }

    @Test("captures one copy only once however often it polls")
    func capturesEachChangeOnce() async {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor { captured.append($0) }
        clipboard.copy("hello")
        await monitor.poll()
        await monitor.poll()
        await monitor.poll()
        #expect(captured.map(\.text) == ["hello"])
    }

    @Test("skips a clip the source marked concealed")
    func skipsConcealedClip() async {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor { captured.append($0) }
        clipboard.copy("hunter2", types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"])
        await monitor.poll()
        #expect(captured.isEmpty)
    }

    @Test("keeps working after a concealed clip")
    func recoversAfterConcealedClip() async {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor { captured.append($0) }
        clipboard.copy("hunter2", types: ["org.nspasteboard.ConcealedType"])
        await monitor.poll()
        clipboard.copy("ordinary")
        await monitor.poll()
        #expect(captured.map(\.text) == ["ordinary"])
    }

    @Test("skips a change carrying no text")
    func skipsNonText() async {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor { captured.append($0) }
        clipboard.copy(nil, types: ["public.png"])
        await monitor.poll()
        #expect(captured.isEmpty)
    }

    @Test("skips empty text")
    func skipsEmptyText() async {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor { captured.append($0) }
        clipboard.copy("")
        await monitor.poll()
        #expect(captured.isEmpty)
    }

    @Test("does not record the clip it wrote itself")
    func ignoresOwnWrite() async {
        var captured: [Clip] = []
        let (_, monitor) = makeMonitor { captured.append($0) }
        monitor.write("pasted by Pastry")
        await monitor.poll()
        #expect(captured.isEmpty)
    }

    @Test("captures the next real copy after one of its own writes")
    func capturesAfterOwnWrite() async {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor { captured.append($0) }
        monitor.write("pasted by Pastry")
        await monitor.poll()
        clipboard.copy("typed by the user")
        await monitor.poll()
        #expect(captured.map(\.text) == ["typed by the user"])
    }

    /// A writer bumps the change count with clearContents() before supplying
    /// its data. Consuming the change on that first failed read would lose the
    /// clip for good.
    @Test("retries a change whose text was not readable yet")
    func retriesAnUnreadableChange() async {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor { captured.append($0) }
        clipboard.copy("arrives a moment late")
        clipboard.failNextRead = true
        await monitor.poll()
        #expect(captured.isEmpty)
        await monitor.poll()
        #expect(captured.map(\.text) == ["arrives a moment late"])
    }

    /// Otherwise a clip holding no text at all would be re-read twice a second
    /// for as long as it sat on the pasteboard.
    @Test("stops retrying a change that never yields text")
    func stopsRetryingAChangeWithNoText() async {
        let (clipboard, monitor) = makeMonitor { _ in }
        clipboard.copy(nil, types: ["public.png"])

        for _ in 0..<5 {
            await monitor.poll()
        }

        // Two reads: the first poll, then the one retry. After that the change
        // is written off and the remaining polls take the change-count
        // early-out, so an image sitting on the pasteboard is not re-read
        // twice a second for as long as it is there.
        #expect(clipboard.readCount == 2)
    }

    /// The old two-step contract — write, then suppress — could swallow a copy
    /// the user made in between. Writing and suppressing are now one call.
    @Test("a copy racing its own write is still captured")
    func doesNotSwallowACopyRacingTheWrite() async {
        var captured: [Clip] = []
        let (clipboard, monitor) = makeMonitor { captured.append($0) }
        monitor.write("pasted by Pastry")
        clipboard.copy("user copied this a moment later")
        await monitor.poll()
        #expect(captured.map(\.text) == ["user copied this a moment later"])
    }
}

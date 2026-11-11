import Foundation
import Testing
@testable import Pastry

/// A pasteboard whose contents the test sets directly.
@MainActor
private final class FakeClipboard: ClipboardSource {
    var changeCount = 0
    var types: [String] = ["public.utf8-plain-text"]
    private var contents: String?

    func string() -> String? { contents }

    /// Mimics a copy: new contents and a bumped change count.
    func copy(_ text: String?, types: [String] = ["public.utf8-plain-text"]) {
        contents = text
        self.types = types
        changeCount += 1
    }
}

@Suite("ClipboardMonitor")
@MainActor
struct ClipboardMonitorTests {
    final class Box { var captured: [String] = [] }

    private func makeMonitor() -> (FakeClipboard, ClipboardMonitor, Box) {
        let clipboard = FakeClipboard()
        let box = Box()
        let monitor = ClipboardMonitor(source: clipboard) { box.captured.append($0) }
        return (clipboard, monitor, box)
    }

    @Test("captures nothing when the pasteboard has not changed")
    func noChangeNoCapture() {
        let (_, monitor, box) = makeMonitor()
        monitor.poll()
        monitor.poll()
        #expect(box.captured.isEmpty)
    }

    @Test("captures newly copied text")
    func capturesNewText() {
        let (clipboard, monitor, box) = makeMonitor()
        clipboard.copy("hello")
        monitor.poll()
        #expect(box.captured == ["hello"])
    }

    @Test("captures one copy only once however often it polls")
    func capturesEachChangeOnce() {
        let (clipboard, monitor, box) = makeMonitor()
        clipboard.copy("hello")
        monitor.poll()
        monitor.poll()
        monitor.poll()
        #expect(box.captured == ["hello"])
    }

    @Test("skips a clip the source marked concealed")
    func skipsConcealedClip() {
        let (clipboard, monitor, box) = makeMonitor()
        clipboard.copy("hunter2", types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"])
        monitor.poll()
        #expect(box.captured.isEmpty)
    }

    @Test("keeps working after a concealed clip")
    func recoversAfterConcealedClip() {
        let (clipboard, monitor, box) = makeMonitor()
        clipboard.copy("hunter2", types: ["org.nspasteboard.ConcealedType"])
        monitor.poll()
        clipboard.copy("ordinary")
        monitor.poll()
        #expect(box.captured == ["ordinary"])
    }

    @Test("skips a change carrying no text")
    func skipsNonText() {
        let (clipboard, monitor, box) = makeMonitor()
        clipboard.copy(nil, types: ["public.png"])
        monitor.poll()
        #expect(box.captured.isEmpty)
    }

    @Test("skips empty text")
    func skipsEmptyText() {
        let (clipboard, monitor, box) = makeMonitor()
        clipboard.copy("")
        monitor.poll()
        #expect(box.captured.isEmpty)
    }

    @Test("ignores the clip Pastry put on the pasteboard itself")
    func ignoresOwnWrite() {
        let (clipboard, monitor, box) = makeMonitor()
        clipboard.copy("pasted by Pastry")
        monitor.ignoreCurrentContents()
        monitor.poll()
        #expect(box.captured.isEmpty)
    }

    @Test("captures the next real copy after one of its own writes")
    func capturesAfterOwnWrite() {
        let (clipboard, monitor, box) = makeMonitor()
        clipboard.copy("pasted by Pastry")
        monitor.ignoreCurrentContents()
        monitor.poll()
        clipboard.copy("typed by the user")
        monitor.poll()
        #expect(box.captured == ["typed by the user"])
    }
}

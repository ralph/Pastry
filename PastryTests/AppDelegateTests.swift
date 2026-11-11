import AppKit
import Testing
@testable import Pastry

@Suite("AppDelegate")
@MainActor
struct AppDelegateTests {
    /// Without this guard every test run would leave a stray status item
    /// behind — and, once later features land, a pasteboard timer and a
    /// registered global hotkey too.
    @Test("installs no status item during a hosted test run")
    func noStatusItemUnderTests() {
        let delegate = AppDelegate()
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        #expect(delegate.statusItem == nil)
    }
}

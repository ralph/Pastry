import AppKit
import Testing
@testable import Pastry

@Suite("AppDelegate menu")
@MainActor
struct AppDelegateTests {
    @Test("offers a single Quit item")
    func hasQuitItem() {
        let menu = AppDelegate().makeMenu()
        #expect(menu.items.count == 1)
        #expect(menu.items.first?.title == "Quit Pastry")
    }

    @Test("Quit is wired to terminate the application")
    func quitTerminates() {
        let item = AppDelegate().makeMenu().items.first
        #expect(item?.action == #selector(NSApplication.terminate(_:)))
    }

    @Test("Quit uses the conventional Command-Q shortcut")
    func quitShortcut() {
        let item = AppDelegate().makeMenu().items.first
        #expect(item?.keyEquivalent == "q")
    }

    @Test("skips installing the status item during tests")
    func noStatusItemUnderTests() {
        let delegate = AppDelegate()
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        #expect(delegate.statusItem == nil)
    }
}

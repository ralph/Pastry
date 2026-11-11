import AppKit
import Testing
@testable import Pastry

@Suite("PreferencesWindowController")
@MainActor
struct PreferencesWindowControllerTests {
    private func makeController() -> PreferencesWindowController {
        PreferencesWindowController(
            preferences: Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
        )
    }

    /// Nothing is built until it is asked for: an agent app that opened a
    /// window at launch would be a window the user never asked to see.
    @Test("builds no window until it is shown")
    func lazyWindow() {
        #expect(makeController().window == nil)
    }

    /// Showing it twice must not leave two Preferences windows on screen.
    @Test("reuses its window")
    func reusesItsWindow() {
        let controller = makeController()
        controller.show()
        let first = controller.window
        controller.show()
        #expect(first === controller.window)
        #expect(controller.window?.isVisible == true)
        controller.window?.close()
    }

    /// Reopened from the menu and from ⌘,, so closing it may not destroy it.
    @Test("survives being closed and opened again")
    func survivesClosing() {
        let controller = makeController()
        controller.show()
        let first = controller.window
        #expect(first?.isReleasedWhenClosed == false)

        controller.window?.close()
        controller.show()
        #expect(first === controller.window)
        #expect(controller.window?.isVisible == true)
        controller.window?.close()
    }

    /// The "Open…" button sends the user to System Settings to approve
    /// Pastry and they come back to a window that was never closed, so the
    /// refresh cannot live only in show().
    @Test("refreshes the login state when its window becomes key")
    func refreshesOnBecomingKey() {
        let item = FakeLoginItem()
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: item)
        let controller = PreferencesWindowController(preferences: preferences)
        controller.show()
        #expect(!preferences.launchAtLogin)

        item.isEnabled = true
        controller.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))
        #expect(preferences.launchAtLogin)
        controller.window?.close()
    }

    /// Without it the window would never be told it became key.
    @Test("is its own window's delegate")
    func isTheWindowDelegate() {
        let controller = makeController()
        controller.show()
        #expect(controller.window?.delegate === controller)
        controller.window?.close()
    }

    @Test("gives the window a title and a close button")
    func looksLikeAWindow() {
        let controller = makeController()
        controller.show()
        #expect(controller.window?.title == "Pastry Settings")
        #expect(controller.window?.styleMask.contains(.closable) == true)
        #expect(controller.window?.styleMask.contains(.titled) == true)
        controller.window?.close()
    }

    /// An empty window would mean the hosting controller never took.
    @Test("fills the window with its content")
    func hasContent() {
        let controller = makeController()
        controller.show()
        let size = controller.window?.contentView?.frame.size ?? .zero
        #expect(size.width > 0)
        #expect(size.height > 0)
        controller.window?.close()
    }
}

import AppKit
import SwiftUI

/// Pastry's own Preferences window.
///
/// Not SwiftUI's `Settings` scene. The only way to summon that from AppKit is
/// `NSApp.sendAction(Selector(("showSettingsWindow:")), …)`, a selector that
/// is not API and has already been renamed once — a breakage a user would
/// find before a test did. Feature 9's key recorder also needs this window's
/// responder chain, which the scene does not hand out. The app keeps an empty
/// `Settings` scene only because `App` requires one.
@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    private(set) var window: NSWindow?
    private let preferences: Preferences

    private static let frameName = NSWindow.FrameAutosaveName("PastrySettings")

    init(preferences: Preferences) {
        self.preferences = preferences
        super.init()
    }

    // MARK: - NSWindowDelegate

    /// The launch-at-login state can change while this window is open and
    /// in the background — the "Open…" button sends the user to System
    /// Settings to approve Pastry, and they come back to a window that was
    /// never closed. Refreshing only in `show()` would leave it saying
    /// "waiting for your approval" after the approval was given.
    func windowDidBecomeKey(_ notification: Notification) {
        preferences.refreshLoginItemState()
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window

        // An agent app has to ask, and has to ask rudely: the cooperative
        // NSApp.activate() does not activate an LSUIElement app at all, so
        // without this the window comes up behind whatever the user was in,
        // with no Dock icon to find it by. Nothing here consults
        // NSApp.isActive, which is never true for this app — the lesson from
        // features 3, 5 and 7.
        NSApp.activate(ignoringOtherApps: true)
        // Covers the case the delegate cannot: a window that is already key
        // gets no windowDidBecomeKey when it is shown again.
        preferences.refreshLoginItemState()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        // Zero, because the size comes from the view a moment later. The
        // view is the only place the window's dimensions are written down.
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pastry Settings"
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: PreferencesView(preferences: preferences)
        )
        window.setContentSize(window.contentViewController?.view.fittingSize ?? .zero)
        // Where the user put it last, falling back to the middle of the
        // screen. Centring on every reopen would move a window the user had
        // deliberately placed, because a closed window is not a visible one.
        //
        // force: true because this window is not resizable, and without it
        // AppKit declines to apply a saved frame to a window that cannot be
        // resized — so the position would never come back.
        if !window.setFrameUsingName(Self.frameName, force: true) {
            window.center()
        }
        window.setFrameAutosaveName(Self.frameName)
        // Closing must not destroy it: it is reopened from the menu and from
        // ⌘,, and show() hands back the same window each time.
        window.isReleasedWhenClosed = false
        return window
    }
}

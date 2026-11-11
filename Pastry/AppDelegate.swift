import AppKit

/// Owns the menu-bar status item.
///
/// The status item is AppKit rather than SwiftUI's `MenuBarExtra` by choice: a
/// search field inside a menu needs a custom-view `NSMenuItem`, which
/// `MenuBarExtra(.menu)` cannot express, and the search field arrives in a
/// later feature. See the design spec under docs/superpowers/specs/.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppEnvironment.isRunningTests else { return }
        installStatusItem()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = MenuBarIcon.image() {
            item.button?.image = image
        } else {
            // A status item with neither image nor title draws zero width. For
            // an agent app that would look exactly like a failed launch, with
            // no way left to quit it, so fall back to something visible.
            item.button?.title = "Pastry"
        }
        item.menu = StatusMenu.make()
        statusItem = item
    }
}

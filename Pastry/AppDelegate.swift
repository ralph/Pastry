import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppEnvironment.isRunningTests else { return }
        installStatusItem()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = MenuBarIcon.image()
        item.menu = makeMenu()
        statusItem = item
    }

    /// Internal rather than private so the menu's contents can be unit tested.
    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Quit Pastry",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        return menu
    }
}

import AppKit

/// Builds the menu shown by the menu-bar status item.
///
/// Separate from `AppDelegate` so its contents can be tested without
/// constructing an application delegate. The clipping rows, search field and
/// Preferences item land here in later features.
enum StatusMenu {
    @MainActor
    static func make() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Quit Pastry",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        return menu
    }
}

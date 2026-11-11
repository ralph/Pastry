import AppKit

/// Owns the menu-bar status item and the clipboard capture pipeline.
///
/// The status item is AppKit rather than SwiftUI's `MenuBarExtra` by choice: a
/// search field inside a menu needs a custom-view `NSMenuItem`, which
/// `MenuBarExtra(.menu)` cannot express, and the search field arrives in a
/// later feature. See the design spec under docs/superpowers/specs/.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var statusItem: NSStatusItem?
    private(set) var store = ClipStore()
    private(set) var monitor: ClipboardMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppEnvironment.isRunningTests else { return }
        installStatusItem()
        startMonitoring()
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

    private func startMonitoring() {
        let monitor = ClipboardMonitor(source: SystemClipboard()) { [weak self] clip in
            self?.record(clip)
        }
        monitor.start()
        self.monitor = monitor
    }

    private func record(_ clip: Clip) {
        store.add(clip)
        // Size and source app only. Clip text is the user's clipboard and
        // never goes to the unified log, which other processes can read.
        // utf8.count is O(1); String.count would walk every grapheme of a
        // multi-megabyte clip on the main actor just to log a number.
        Log.clipboard.info(
            "captured \(clip.text.utf8.count) bytes from \(clip.appName ?? "an unknown app", privacy: .public); history now \(self.store.count)"
        )
    }
}

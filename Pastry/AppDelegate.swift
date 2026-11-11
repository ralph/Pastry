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
    /// Retained here because NSMenu's delegate and NSMenuItem's target are both
    /// weak, so nothing else keeps the menu's controller alive.
    private var statusMenu: StatusMenu?
    private(set) var store = ClipStore()
    private(set) var monitor: ClipboardMonitor?
    private(set) var paster: Paster?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppEnvironment.isRunningTests else { return }
        startMonitoring()
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
        let statusMenu = StatusMenu(store: store) { [weak self] clip in
            self?.choose(clip)
        }
        item.menu = statusMenu.menu
        self.statusMenu = statusMenu
        statusItem = item
    }

    private func startMonitoring() {
        let monitor = ClipboardMonitor(source: SystemClipboard()) { [weak self] clip in
            self?.record(clip)
        }
        monitor.start()
        self.monitor = monitor
        // Pastes are written through the monitor so the clip Pastry puts on
        // the pasteboard is not captured straight back as a new one. Captured
        // strongly: this delegate owns both for the process lifetime, so there
        // is no cycle, and a nil monitor would mean pasting stale text.
        paster = Paster(write: { text in monitor.write(text) })
    }

    /// Pastes a chosen clip into the application the user came from.
    private func choose(_ clip: Clip) {
        store.moveToTop(clip)
        Task { [weak self] in
            guard let outcome = await self?.paster?.paste(clip.text) else { return }
            Log.clipboard.info(
                "chose a clip of \(clip.text.utf8.count) bytes: \(outcome.rawValue, privacy: .public)"
            )
        }
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

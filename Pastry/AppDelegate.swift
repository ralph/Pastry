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
    /// Whatever was active when the menu opened, so focus can go back to it.
    private var previousApp: NSRunningApplication?
    /// True between cancelling the menu and the reopen we asked for.
    private var isReopeningMenu = false

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
        statusMenu.onWillOpen = { [weak self] in self?.menuWillOpen() ?? true }
        statusMenu.onDidClose = { [weak self] in self?.menuDidClose() }
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

    /// Makes the menu's search field usable.
    ///
    /// A status menu tracks without activating an `LSUIElement` application,
    /// so nothing inside it can become first responder and the search field
    /// never sees a keystroke. The only way through is to cancel the menu,
    /// activate, and put it back up — which is what Flycut does.
    ///
    /// Returns false when it cancelled the menu, so this opening stops here.
    private func menuWillOpen() -> Bool {
        // Set for exactly one reopen. Without it, an activation that does not
        // take effect leaves this cancelling and reopening the menu forever,
        // which is a hung app at 50% CPU rather than a missing focus ring.
        if isReopeningMenu {
            isReopeningMenu = false
            focusSearchFieldShortly()
            return true
        }

        guard !NSApp.isActive else {
            focusSearchFieldShortly()
            return true
        }

        isReopeningMenu = true
        previousApp = NSWorkspace.shared.frontmostApplication
        // Activating would close the menu anyway, so close it deliberately.
        statusMenu?.menu.cancelTracking()
        // Must ignore other apps: the cooperative NSApp.activate() does not
        // activate an LSUIElement agent, and without activation the search
        // field can never take focus.
        NSApp.activate(ignoringOtherApps: true)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard let button = self?.statusItem?.button else { return }
            // Reopened by clicking the status button, which shows the menu
            // already attached to it. Flycut reopened by replaying the
            // original mouse event, which stopped working on macOS 27
            // (upstream 8a24014); its replacement, popUpStatusItemMenu:, has
            // been deprecated since 10.14 in favour of the menu property —
            // which is exactly what this goes through.
            button.performClick(nil)
        }
        return false
    }

    private func menuDidClose() {
        // Clear the latch too: if the reopen never arrived, the next opening
        // must start the dance afresh rather than assume it is the reopen.
        isReopeningMenu = false
        // Hand focus back where it came from. A paste also hides Pastry, which
        // has the same effect; this covers dismissing without choosing.
        previousApp?.activate()
        previousApp = nil
    }

    private func focusSearchFieldShortly() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            self?.statusMenu?.focusSearchField()
        }
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

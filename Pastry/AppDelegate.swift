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
    private let history = HistoryStore()
    private var saver: DebouncedSaver?
    private(set) var monitor: ClipboardMonitor?
    private(set) var paster: Paster?
    private var bezel: BezelController?
    private var hotKey: HotKey?
    /// Whatever was active when the menu opened, so focus can go back to it.
    private var previousApp: NSRunningApplication?
    /// True between cancelling the menu and the reopen we asked for.
    private var isReopeningMenu = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppEnvironment.isRunningTests else { return }
        restoreHistory()
        startMonitoring()
        installStatusItem()
        installBezel()
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
        statusMenu.onWillOpen = { [weak self] in self?.menuWillOpen() }
        statusMenu.onDidClose = { [weak self] in self?.menuDidClose() }
        item.menu = statusMenu.menu
        self.statusMenu = statusMenu
        statusItem = item
    }

    private func restoreHistory() {
        store.load(history.load())

        let saver = DebouncedSaver { [history] clips in history.save(clips) }
        store.onChange = { [weak self, weak saver] urgency in
            guard let self, let saver else { return }
            saver.schedule(self.store.clips)
            // Deleting is meant to take effect now, not at the next quiet
            // moment: a force quit in between would bring the clips back.
            if urgency == .immediate { saver.flush() }
        }
        self.saver = saver
        Log.clipboard.info("restored \(self.store.count) clips from disk")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // A pending write has no later moment to wait for.
        saver?.flush()
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

    /// How long to let activation settle before putting the menu back up.
    private static let activationDelay: Duration = .milliseconds(200)

    /// Makes the menu's search field usable.
    ///
    /// A status menu tracks without activating an `LSUIElement` application,
    /// so nothing inside it can become first responder and the search field
    /// never sees a keystroke. The only way through is to cancel the menu,
    /// activate, and put it back up — which is what Flycut does.
    ///
    /// Deliberately consults no "are we active yet" signal, because none of
    /// them report the activation. Measured at the moment the reopen fires and
    /// the search field goes on to work: `NSApp.isActive` is false and
    /// `NSWorkspace.frontmostApplication` is still the other application.
    /// Guarding on either therefore breaks the normal case — `isActive` was
    /// tried twice, once spinning at 50% CPU and once leaving the click dead.
    /// The latch below is the only thing that distinguishes the two openings.
    ///
    /// The cost of having no signal: switching applications during the delay
    /// still reopens the menu, over whatever is frontmost by then. Rare, and
    /// recoverable by pressing Escape.
    private func menuWillOpen() {
        if isReopeningMenu {
            // This is the reopen we asked for; the field can take focus now.
            isReopeningMenu = false
            afterActivationDelay { $0.statusMenu?.focusSearchField() }
            return
        }

        isReopeningMenu = true
        previousApp = NSWorkspace.shared.frontmostApplication
        // Activating would close the menu anyway, so close it deliberately.
        statusMenu?.menu.cancelTracking()
        // Must ignore other apps: the cooperative NSApp.activate() does not
        // activate an agent app at all.
        NSApp.activate(ignoringOtherApps: true)

        afterActivationDelay { delegate in
            // An opening that already happened consumes the latch, so a second
            // click inside the window cannot be followed by a stray reopen
            // that toggles the menu shut again.
            guard delegate.isReopeningMenu, let button = delegate.statusItem?.button else {
                return
            }
            // Reopened by clicking the status button, which shows the menu
            // already attached to it. Flycut reopened by replaying the
            // original mouse event, which stopped working on macOS 27
            // (upstream 8a24014); its replacement, popUpStatusItemMenu:, has
            // been deprecated since 10.14 in favour of the menu property —
            // which is exactly what this goes through. Verified by hand.
            button.performClick(nil)
        }
    }

    private func menuDidClose() {
        // Cancelling for the reopen may deliver this; the dance is still in
        // progress, so leave the remembered application alone. Without this,
        // the reopen would race a counter-activation and the field would come
        // up unfocused with no way back to the app the user came from.
        guard !isReopeningMenu else { return }
        // Plain activate: unlike NSApplication's, NSRunningApplication's
        // ignoringOtherApps option is a documented no-op since macOS 14.
        // Pastry is frontmost here anyway, so yielding is uncontested.
        previousApp?.activate()
        previousApp = nil
    }

    private func afterActivationDelay(_ body: @escaping @MainActor (AppDelegate) -> Void) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.activationDelay)
            guard let self else { return }
            body(self)
        }
    }

    private func installBezel() {
        // One value for the combination, shared by the registration and by
        // the bezel, which has to know which key walks the history and which
        // modifiers releasing ends the interaction. Feature 9 makes it
        // configurable, and this is the single place it will come from.
        let combination = HotKeyCombination.commandShiftV

        let bezel = BezelController(store: store, hotKey: combination) { [weak self] clip in
            self?.choose(clip)
        }
        self.bezel = bezel

        // A nil hotkey means the combination is already taken; HotKey logs
        // the reason. The menu still works, so this is not fatal.
        hotKey = HotKey(combination: combination) { [weak self] in
            guard let self else { return }
            // A paste in flight sends ⌘V to whatever window is key once the
            // focus handoff has settled. Showing the bezel now would make it
            // that window, so the keystroke would walk its history instead
            // of pasting and the clip would go nowhere. The wait is 0.2 s.
            guard paster?.isPasting != true else { return }
            bezel.hotKeyPressed()
        }
    }

    /// Pastes a chosen clip into the application the user came from.
    private func choose(_ clip: Clip) {
        Task { [weak self] in
            guard let self, let paster else { return }
            let outcome = await paster.paste(clip.text)
            // Reordered only once something actually happened. A paste that
            // overlaps one already in flight is dropped, and moving the clip
            // to the top for it would rearrange the history visibly with no
            // pasted text to show for it.
            if outcome != .alreadyPasting { store.moveToTop(clip) }
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

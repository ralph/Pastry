import AppKit

/// The menu behind the status item.
///
/// Clip rows are refreshed as the menu is about to open, and again as the user
/// types, so they are always current without observing the store.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate, NSSearchFieldDelegate {
    let menu = NSMenu()

    /// What the user has typed into the search field.
    private(set) var query = ""

    var onWillOpen: (() -> Void)?
    var onDidClose: (() -> Void)?
    var onOpenPreferences: (() -> Void)?

    private let store: ClipStore
    /// Settable: lowering it in Preferences has to shorten the menu now,
    /// not at the next launch. The rows are rebuilt before every opening, so
    /// nothing else has to happen when it changes.
    var displayCount: Int
    private let onSelect: (Clip) -> Void

    /// Internal so tests can drive the real text-change path.
    let searchField = NSSearchField()

    /// Internal so tests can find the row by identity instead of position.
    private(set) lazy var searchFieldItem: NSMenuItem = {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 28))
        searchField.frame = NSRect(x: 12, y: 2, width: 216, height: 24)
        searchField.delegate = self
        container.addSubview(searchField)
        let item = NSMenuItem()
        item.view = container
        return item
    }()

    /// Whatever held focus in the menu before the field took it, so an arrow
    /// key can hand control back to the rows.
    private weak var responderBeforeSearch: NSResponder?

    init(store: ClipStore, displayCount: Int = 30, onSelect: @escaping (Clip) -> Void) {
        self.store = store
        self.displayCount = displayCount
        self.onSelect = onSelect
        super.init()
        menu.delegate = self
        buildFixedItems()
        refreshClipRows()
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshClipRows()
    }

    func menuWillOpen(_ menu: NSMenu) {
        onWillOpen?()
    }

    func menuDidClose(_ menu: NSMenu) {
        // A filter that outlived the menu would silently hide clips next time
        // it opened, with nothing on screen to explain why.
        setQuery("")
        onDidClose?()
    }

    /// Called once the application is active and the menu is open again — a
    /// status menu tracks without activating an agent app, so until then
    /// nothing in it can be first responder.
    func focusSearchField() {
        guard let window = searchField.window else { return }

        // Never remember the field, or the field editor it is already using,
        // as the way back out: the arrow keys would then restore the very
        // responder they are trying to leave and navigation would be dead.
        // Reachable by clicking into the field before this callback runs.
        let current = window.firstResponder
        if current !== searchField, current !== searchField.currentEditor() {
            responderBeforeSearch = current
        }

        window.makeFirstResponder(searchField)
    }

    // MARK: - NSSearchFieldDelegate

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSSearchField, field === searchField else {
            return
        }
        setQuery(field.stringValue)
    }

    /// Lets an arrow key out of the search field and into the rows.
    ///
    /// While the field is first responder its editor swallows the arrows, so
    /// someone who typed to narrow the list could not reach the row they were
    /// aiming for without the mouse. Handing the responder back is enough on
    /// its own: that very first press then lands on the menu and moves the
    /// highlight. Flycut additionally re-posted a synthetic arrow here, which
    /// on macOS 27 closes the menu instead — verified by hand.
    func control(
        _ control: NSControl,
        textView: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)), #selector(NSResponder.moveUp(_:)):
            // nil resigns first responder, which leaves the menu free to take
            // the key — the right fallback when there was nothing to remember.
            searchField.window?.makeFirstResponder(responderBeforeSearch)
            responderBeforeSearch = nil
            return true
        default:
            return false
        }
    }

    // MARK: - Building

    /// The rows that never change, built once.
    ///
    /// Once, because the search field lives in one of them: removing it from
    /// the menu ends its field editor, so a rebuild that took it out would
    /// drop focus after a single keystroke.
    private func buildFixedItems() {
        menu.addItem(searchFieldItem)
        menu.addItem(.separator())
        addItem("Clear All", action: #selector(clearAll), target: self)
        addItem("Merge All", action: #selector(mergeAll), target: self)
        menu.addItem(.separator())
        addItem("Settings…", action: #selector(preferences), keyEquivalent: ",", target: self)
        addItem("About Pastry", action: #selector(about), target: self)
        addItem("Quit Pastry", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    /// Replaces just the clip rows, which sit above the search field.
    ///
    /// Safe to call while the menu is open — which is what filtering as the
    /// user types does — because it never touches the row holding the field.
    private func refreshClipRows() {
        // Bounded by the field's own position rather than by scanning until
        // it is found: if the field were ever missing, scanning would strip
        // the whole menu, including Quit, from an app with no other UI.
        let existingRows = menu.index(of: searchFieldItem)
        guard existingRows >= 0 else { return }
        for _ in 0..<existingRows {
            menu.removeItem(at: 0)
        }

        let clips = store.search(query, limit: displayCount)
        guard !clips.isEmpty else {
            // A nil action is what disables the row. Setting isEnabled would
            // do nothing: NSMenu.autoenablesItems is on, and it recomputes the
            // enabled state at display time.
            menu.insertItem(
                withTitle: store.count == 0 ? "No clippings" : "No matches",
                action: nil,
                keyEquivalent: "",
                at: 0
            )
            return
        }

        for (index, clip) in clips.enumerated() {
            let item = menu.insertItem(
                withTitle: clip.displayText,
                action: #selector(selectClip(_:)),
                keyEquivalent: "",
                at: index
            )
            item.target = self
            // The row carries the clip itself, not its position. A capture can
            // land while the menu is open — the monitor keeps polling — which
            // shifts every index, and an index-carrying row would then act on
            // a different clip than the one whose title the user read.
            item.representedObject = clip
        }
    }

    @discardableResult
    @objc private func preferences() {
        onOpenPreferences?()
    }

    private func addItem(
        _ title: String,
        action: Selector?,
        keyEquivalent: String = "",
        target: AnyObject? = nil
    ) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: keyEquivalent)
        // A nil target sends the action up the responder chain, which is how
        // Quit reaches NSApplication.
        item.target = target
        return item
    }

    private func setQuery(_ text: String) {
        query = text
        searchField.stringValue = text
        refreshClipRows()
    }

    // MARK: - Actions

    @objc private func selectClip(_ sender: NSMenuItem) {
        guard let clip = sender.representedObject as? Clip else { return }
        onSelect(clip)
    }

    @objc private func clearAll() {
        store.clear()
    }

    @objc private func mergeAll() {
        store.merge()
    }

    @objc private func about() {
        // Ignoring other apps on purpose: the cooperative form does not
        // activate an agent app, and the panel would open behind everything.
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}

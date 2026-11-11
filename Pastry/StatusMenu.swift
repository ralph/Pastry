import AppKit

/// Container for the menu's search field.
///
/// A distinct type so the tests and the delegate can find that row without
/// depending on its position.
final class SearchFieldView: NSView {}

/// The menu behind the status item.
///
/// Rows are rebuilt as the menu is about to open rather than whenever the
/// history changes: the menu is then always current, there is nothing to
/// observe, and a capture while the menu is closed costs no UI work.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate, NSSearchFieldDelegate {
    let menu = NSMenu()

    /// What the user has typed into the search field.
    private(set) var query = ""

    /// Returning false means the opening was intercepted and the menu
    /// cancelled, so nothing further should happen this time round.
    var onWillOpen: (() -> Bool)?
    var onDidClose: (() -> Void)?

    private let store: ClipStore
    private let displayCount: Int
    private let onSelect: (Clip) -> Void

    private let searchField = NSSearchField()

    /// Built once and reused across rebuilds. Rebuilding it would throw away
    /// the text the user is in the middle of typing.
    private lazy var searchFieldItem: NSMenuItem = {
        let container = SearchFieldView(frame: NSRect(x: 0, y: 0, width: 240, height: 28))
        searchField.frame = NSRect(x: 12, y: 2, width: 216, height: 24)
        // The field's target/action never fires while the menu is tracking —
        // the text arrives but the action does not — so changes come through
        // the text-editing delegate instead, which is what Flycut relied on.
        searchField.delegate = self
        container.addSubview(searchField)
        let item = NSMenuItem()
        item.view = container
        return item
    }()

    init(store: ClipStore, displayCount: Int = 30, onSelect: @escaping (Clip) -> Void) {
        self.store = store
        self.displayCount = displayCount
        self.onSelect = onSelect
        super.init()
        menu.delegate = self
        buildFixedItems()
        refreshClipRows()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshClipRows()
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard onWillOpen?() ?? true else { return }
    }

    func menuDidClose(_ menu: NSMenu) {
        resetQuery()
        onDidClose?()
    }

    /// Called once the application is active and the menu is open again — a
    /// status menu tracks without activating an agent app, so until then
    /// nothing in it can be first responder.
    func focusSearchField() {
        searchField.window?.makeFirstResponder(searchField)
    }

    func resetQuery() {
        query = ""
        searchField.stringValue = ""
    }

    /// Test seam: drives the same path the field's action does, with no event
    /// loop to type into.
    func setQueryForTesting(_ text: String) {
        searchField.stringValue = text
        query = text
        refreshClipRows()
    }

    /// The rows that never change, built once.
    ///
    /// Built once because the search field lives in one of them: removing it
    /// from the menu ends its field editor, so a rebuild that took it out
    /// would drop focus after a single keystroke.
    private func buildFixedItems() {
        menu.removeAllItems()
        menu.addItem(searchFieldItem)
        menu.addItem(.separator())
        addItem("Clear All", action: #selector(clearAll), target: self)
        addItem("Merge All", action: #selector(mergeAll), target: self)
        menu.addItem(.separator())
        addItem("About Pastry", action: #selector(about), target: self)
        addItem("Quit Pastry", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    /// Replaces just the clip rows, which sit above the search field.
    ///
    /// Safe to call while the menu is open — that is what filtering as the
    /// user types does — because it never touches the row holding the field.
    private func refreshClipRows() {
        while let first = menu.items.first, first !== searchFieldItem {
            menu.removeItem(first)
        }

        let clips = store.search(query, limit: displayCount)
        guard !clips.isEmpty else {
            // A nil action is what disables the row. Setting isEnabled would
            // do nothing: NSMenu.autoenablesItems is on, and it recomputes the
            // enabled state at display time.
            let empty = NSMenuItem(
                title: store.count == 0 ? "No clippings" : "No matches",
                action: nil,
                keyEquivalent: ""
            )
            menu.insertItem(empty, at: 0)
            return
        }

        for (index, clip) in clips.enumerated() {
            let item = NSMenuItem(
                title: clip.displayText,
                action: #selector(selectClip(_:)),
                keyEquivalent: ""
            )
            item.target = self
            // The row carries the clip itself, not its position. A capture can
            // land while the menu is open — the monitor keeps polling — which
            // shifts every index, and an index-carrying row would then act on
            // a different clip than the one whose title the user read.
            item.representedObject = clip
            menu.insertItem(item, at: index)
        }
    }

    @discardableResult
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

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSSearchField, field === searchField else { return }
        query = field.stringValue
        refreshClipRows()
    }

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

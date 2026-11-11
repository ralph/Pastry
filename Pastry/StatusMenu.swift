import AppKit

/// The menu behind the status item.
///
/// Rows are rebuilt as the menu is about to open rather than whenever the
/// history changes: the menu is then always current, there is nothing to
/// observe, and a capture while the menu is closed costs no UI work.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    let menu = NSMenu()

    private let store: ClipStore
    private let displayCount: Int
    private let onSelect: (Clip) -> Void

    init(store: ClipStore, displayCount: Int = 30, onSelect: @escaping (Clip) -> Void) {
        self.store = store
        self.displayCount = displayCount
        self.onSelect = onSelect
        super.init()
        menu.delegate = self
        // AppKit rebuilds before every display; this is only so the menu is
        // never in an empty state if something reads it before then.
        rebuild()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild()
    }

    private func rebuild() {
        menu.removeAllItems()
        addClipRows()
        menu.addItem(.separator())
        addItem("Clear All", action: #selector(clearAll), target: self)
        addItem("Merge All", action: #selector(mergeAll), target: self)
        menu.addItem(.separator())
        addItem("About Pastry", action: #selector(about), target: self)
        addItem("Quit Pastry", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    private func addClipRows() {
        let clips = store.clips.prefix(displayCount)
        guard !clips.isEmpty else {
            // A nil action is what disables the row. Setting isEnabled would
            // do nothing: NSMenu.autoenablesItems is on, and it recomputes the
            // enabled state at display time.
            addItem("No clippings", action: nil)
            return
        }
        for clip in clips {
            let item = addItem(clip.displayText, action: #selector(selectClip(_:)), target: self)
            // The row carries the clip itself, not its position. A capture can
            // land while the menu is open — the monitor keeps polling — which
            // shifts every index, and an index-carrying row would then act on
            // a different clip than the one whose title the user read.
            item.representedObject = clip
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
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}

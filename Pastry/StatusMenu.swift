import AppKit

/// The menu behind the status item.
///
/// Rows are rebuilt as the menu is about to open rather than whenever the
/// history changes: the menu is then always current, there is nothing to
/// observe, and a capture while the menu is closed costs no UI work at all.
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
        rebuild()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild()
    }

    func rebuild() {
        menu.removeAllItems()
        addClipRows()
        menu.addItem(.separator())
        addItem("Clear All", #selector(clearAll))
        addItem("Merge All", #selector(mergeAll))
        menu.addItem(.separator())
        addItem("About Pastry", #selector(about))
        menu.addItem(
            withTitle: "Quit Pastry",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
    }

    private func addClipRows() {
        let clips = store.clips.prefix(displayCount)
        guard !clips.isEmpty else {
            let empty = NSMenuItem(title: "No clippings", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }
        for (index, clip) in clips.enumerated() {
            let item = NSMenuItem(
                title: clip.displayText,
                action: #selector(selectClip(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = index
            menu.addItem(item)
        }
    }

    private func addItem(_ title: String, _ action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc private func selectClip(_ sender: NSMenuItem) {
        // The tag is the row's index at the time the menu was built. A capture
        // can land while the menu is open, so read through the store rather
        // than holding the clip, and tolerate the index being gone.
        guard let clip = store.clip(at: sender.tag) else { return }
        store.moveToTop(at: sender.tag)
        onSelect(clip)
    }

    @objc private func clearAll() {
        store.clear()
    }

    @objc private func mergeAll() {
        store.merge()
    }

    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}

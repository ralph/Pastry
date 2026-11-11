import AppKit
import SwiftUI

/// Drives the bezel: shows it, walks the history, and pastes on release.
@MainActor
final class BezelController: BezelPanelDelegate {
    private let store: ClipStore
    private let paste: (Clip) -> Void
    private let hotKey: HotKeyCombination

    private var panel: BezelPanel?
    private var hosting: NSHostingView<BezelView>?
    private var selection = BezelSelection(count: 0)
    /// The clip currently on screen.
    ///
    /// Held rather than re-read from `selection.position` when the user acts:
    /// capture keeps running while the bezel is open, and a copy made in
    /// another application inserts at the top and shifts every index down.
    /// Resolving the index again at that point would paste or delete a clip
    /// other than the one the user is looking at.
    private var displayed: Clip?

    private(set) var isShowing = false

    init(
        store: ClipStore,
        hotKey: HotKeyCombination,
        paste: @escaping (Clip) -> Void
    ) {
        self.store = store
        self.hotKey = hotKey
        self.paste = paste
    }

    /// The hotkey: opens the bezel, or walks one clip older if it is already
    /// open. That is what makes holding ⌘⇧ and tapping V repeatedly work.
    func hotKeyPressed() {
        guard isShowing else {
            show()
            return
        }
        perform(.older)
    }

    private func show() {
        selection = BezelSelection(count: store.count)

        let panel = self.panel ?? BezelPanel(size: BezelView.size)
        panel.keyDelegate = self
        self.panel = panel

        let hosting = self.hosting ?? NSHostingView(rootView: currentView())
        if self.hosting == nil {
            panel.contentView = hosting
            self.hosting = hosting
        }

        render()
        panel.centreOnActiveScreen()
        // Pasting hides the whole application to hand focus back, and a
        // hidden application's windows stay ordered out however often they
        // are told to come forward. Without activating, so the paste after
        // this one still lands where the user is typing.
        NSApp.unhideWithoutActivation()
        // Key without activating: the paste must land in the app the user came
        // from, and only a key window sees the modifier release.
        panel.makeKeyAndOrderFront(nil)
        isShowing = true
    }

    func hide() {
        // Cleared first: ordering out gives up key status, which comes back
        // through bezelPanelDidResignKey, and the flag is what stops that
        // from running the dismissal a second time.
        isShowing = false
        displayed = nil
        panel?.orderOut(nil)
    }

    private func currentView() -> BezelView {
        BezelView(
            clip: displayed,
            position: selection.position,
            count: selection.count
        )
    }

    private func render() {
        selection.count = store.count
        selection.clamp()
        displayed = store.clip(at: selection.position)
        hosting?.rootView = currentView()
    }

    // MARK: - BezelPanelDelegate

    func bezelPanel(_ panel: BezelPanel, didChangeFlags event: NSEvent) {
        guard isShowing else { return }
        // Letting go of the modifiers is the primary way to paste: the user
        // held ⌘⇧, tapped to the clip they wanted, and let go. A combination
        // with no modifiers at all has nothing to let go of, so it pastes
        // with Return instead — without this guard the first flagsChanged
        // after opening would paste immediately.
        guard !hotKey.modifiers.isEmpty else { return }
        if event.modifierFlags.intersection(hotKey.modifiers).isEmpty {
            perform(.paste)
        }
    }

    func bezelPanelDidCancel(_ panel: BezelPanel) {
        guard isShowing else { return }
        perform(.cancel)
    }

    func bezelPanelDidResignKey(_ panel: BezelPanel) {
        guard isShowing else { return }
        // Nothing is pasted: the user went somewhere else rather than
        // choosing a clip.
        perform(.cancel)
    }

    func bezelPanel(_ panel: BezelPanel, didReceiveKeyDown event: NSEvent) {
        guard isShowing else { return }
        let action = BezelKeyMap.action(
            character: event.charactersIgnoringModifiers?.first,
            keyCode: event.keyCode,
            modifiers: event.modifierFlags,
            hotKey: hotKey
        )
        perform(action)
    }

    private func perform(_ action: BezelAction) {
        switch action {
        case .older: selection.older()
        case .newer: selection.newer()
        case .tenOlder: selection.tenOlder()
        case .tenNewer: selection.tenNewer()
        case .first: selection.first()
        case .last: selection.last()
        case .jump(let index): selection.jump(to: index)

        case .paste:
            let clip = displayed
            hide()
            if let clip { paste(clip) }
            return

        case .delete:
            if let displayed { store.remove(displayed) }
            // Stays open: deleting is usually done several at a time.

        case .cancel:
            hide()
            return

        case .ignored:
            return
        }

        render()
    }
}

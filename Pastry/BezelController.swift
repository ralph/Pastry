import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Drives the bezel: shows it, walks the history, and pastes on release.
@MainActor
final class BezelController: BezelPanelDelegate {
    private let store: ClipStore
    private let paste: (Clip) -> Void
    private let openPreferences: () -> Void

    private var panel: BezelPanel?
    private var hosting: NSHostingView<BezelView>?
    private var selection = BezelSelection(count: 0)

    private(set) var isShowing = false

    init(
        store: ClipStore,
        paste: @escaping (Clip) -> Void,
        openPreferences: @escaping () -> Void = {}
    ) {
        self.store = store
        self.paste = paste
        self.openPreferences = openPreferences
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

        let panel = self.panel ?? BezelPanel(size: NSSize(width: 520, height: 280))
        panel.keyDelegate = self
        self.panel = panel

        let hosting = self.hosting ?? NSHostingView(rootView: currentView())
        if self.hosting == nil {
            panel.contentView = hosting
            self.hosting = hosting
        }

        render()
        panel.centreOnActiveScreen()
        // Key without activating: the paste must land in the app the user came
        // from, and only a key window sees the modifier release.
        panel.makeKeyAndOrderFront(nil)
        isShowing = true
    }

    func hide() {
        panel?.orderOut(nil)
        isShowing = false
    }

    private func currentView() -> BezelView {
        BezelView(
            clip: store.clip(at: selection.position),
            position: selection.position,
            count: selection.count
        )
    }

    private func render() {
        selection.count = store.count
        selection.clamp()
        hosting?.rootView = currentView()
    }

    // MARK: - BezelPanelDelegate

    func bezelPanel(_ panel: BezelPanel, didChangeFlags event: NSEvent) {
        guard isShowing else { return }
        // Letting go of the modifiers is the primary way to paste: the user
        // held ⌘⇧, tapped to the clip they wanted, and let go.
        if event.modifierFlags.intersection([.command, .shift]).isEmpty {
            perform(.paste)
        }
    }

    func bezelPanelDidCancel(_ panel: BezelPanel) {
        guard isShowing else { return }
        perform(.cancel)
    }

    func bezelPanel(_ panel: BezelPanel, didReceiveKeyDown event: NSEvent) {
        guard isShowing else { return }
        let action = BezelKeyMap.action(
            character: event.charactersIgnoringModifiers?.first,
            keyCode: event.keyCode,
            hasCommand: event.modifierFlags.contains(.command),
            hasShift: event.modifierFlags.contains(.shift),
            isHotKeyCode: event.keyCode == UInt16(kVK_ANSI_V)
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
            let clip = store.clip(at: selection.position)
            hide()
            if let clip { paste(clip) }
            return

        case .delete:
            store.remove(at: selection.position)
            // Stays open: deleting is usually done several at a time.

        case .cancel:
            hide()
            return

        case .preferences:
            hide()
            openPreferences()
            return

        case .ignored:
            return
        }

        render()
    }
}

import AppKit
import SwiftUI

/// Drives the bezel: shows it, walks the history, and pastes on release.
@MainActor
final class BezelController: BezelPanelDelegate {
    private let store: ClipStore
    private let paste: (Clip) -> Void
    private let openPreferences: () -> Void
    /// Settable: feature 9 lets the user change the combination while the
    /// app runs. Everything that reads it — the release check and the key
    /// map — reads it afresh each time, so nothing else happens on a change.
    var hotKey: HotKeyCombination

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

    /// `openPreferences` has no default on purpose. A default of `{}` is
    /// what let ⌘, silently dismiss the bezel and do nothing in feature 7;
    /// making the argument compulsory is what stops that happening again.
    init(
        store: ClipStore,
        hotKey: HotKeyCombination,
        paste: @escaping (Clip) -> Void,
        openPreferences: @escaping () -> Void
    ) {
        self.store = store
        self.hotKey = hotKey
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
        // Carbon matched the whole combination to fire the hotkey, so the
        // modifiers are held at this instant by definition. Reading them
        // here is what makes the reconcile at the end safe: if this snapshot
        // does not show them held, the live state cannot be trusted, and the
        // reconcile is skipped rather than pasting the moment the bezel
        // appears. The worst case is the stranded bezel below, not a paste
        // nobody asked for.
        let seenHeld = !hotKey.modifiers.isEmpty
            && NSEvent.modifierFlags.intersection(hotKey.modifiers) == hotKey.modifiers

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
        // Marked as showing before it is ordered in, not after: losing key
        // status is a dismissal, and the delegate ignores one while this is
        // false. Were it set afterwards, a panel that gave up key status on
        // the way in would have its dismissal dropped and stay on screen
        // with nothing able to close it.
        isShowing = true
        // Key without activating: the paste must land in the app the user came
        // from, and only a key window sees the modifier release.
        panel.makeKeyAndOrderFront(nil)

        // A release that happened before the panel had key status went to the
        // application the user came from, and no later flagsChanged will
        // arrive to replace it — the bezel would sit there holding modifiers
        // nobody is pressing. Building the hosting view the first time is
        // slow enough to lose a quick tap this way. Reading the live state
        // once the panel is key closes that window, and makes tapping the
        // hotkey and letting straight go paste the newest clip, which is
        // what the gesture looks like it should do.
        if seenHeld, NSEvent.modifierFlags.intersection(hotKey.modifiers).isEmpty {
            perform(.paste)
        }
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

    /// Puts the cursor back on the clip that is on screen.
    ///
    /// Capture keeps running while the bezel is open, and a copy made in
    /// another application inserts at the top, moving every index down.
    /// Without this the next "older" would land on the clip already shown —
    /// and after two captures it would move towards newer instead.
    private func rebase() {
        selection.count = store.count
        if let displayed, let index = store.firstIndex(of: displayed) {
            selection.jump(to: index)
        }
        selection.clamp()
    }

    private func perform(_ action: BezelAction) {
        rebase()
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

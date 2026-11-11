import AppKit

/// The window the bezel is drawn in.
///
/// Non-activating on purpose: if summoning the bezel activated Pastry, the
/// paste that follows would land in Pastry rather than in the application the
/// user was typing in. Borderless windows refuse key status by default, and
/// without it the modifier release that triggers the paste is never seen — so
/// this takes keys without taking activation.
@MainActor
protocol BezelPanelDelegate: AnyObject {
    func bezelPanel(_ panel: BezelPanel, didReceiveKeyDown event: NSEvent)
    func bezelPanel(_ panel: BezelPanel, didChangeFlags event: NSEvent)
    func bezelPanelDidCancel(_ panel: BezelPanel)
}

final class BezelPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    weak var keyDelegate: BezelPanelDelegate?

    // Handled on the window rather than through an NSEvent local monitor: a
    // local monitor only sees events dispatched to the *active* application,
    // and this panel deliberately never activates Pastry. A key window of an
    // inactive app still receives key events here.
    override func keyDown(with event: NSEvent) {
        keyDelegate?.bezelPanel(self, didReceiveKeyDown: event)
    }

    override func flagsChanged(with event: NSEvent) {
        keyDelegate?.bezelPanel(self, didChangeFlags: event)
    }

    // Escape never arrives at keyDown: AppKit turns it into a cancel sent
    // down the responder chain, so without this the bezel ignored Escape and
    // the modifier release that followed pasted instead of dismissing.
    override func cancelOperation(_ sender: Any?) {
        keyDelegate?.bezelPanelDidCancel(self)
    }

    init(size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        // Stays put when the user clicks away, so releasing the modifiers is
        // still what dismisses it.
        hidesOnDeactivate = false
        isMovable = false
        // Reachable from whichever Space the user is on, including over a
        // full-screen application.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    /// Centres on the screen the pointer is on, which is where the user is
    /// looking on a multi-display setup.
    func centreOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        setFrameOrigin(
            NSPoint(
                x: visible.midX - frame.width / 2,
                y: visible.midY - frame.height / 2
            )
        )
    }
}

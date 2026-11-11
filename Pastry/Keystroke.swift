import Carbon.HIToolbox
import CoreGraphics

/// Synthesises the paste keystroke.
enum Keystroke {
    /// Sends ⌘V to whatever has keyboard focus.
    ///
    /// Posted by **key code**, not by character, so the keystroke is the one
    /// physically at the V position on any keyboard layout — pasting used to
    /// fail on non-QWERTY layouts otherwise.
    ///
    /// The flags carry `0x8` alongside the command mask. That bit identifies
    /// the *left* command key, and some applications check for it rather than
    /// the generic modifier.
    @MainActor
    static func commandV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let v = CGKeyCode(kVK_ANSI_V)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        else { return }

        let flags = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x000008)
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

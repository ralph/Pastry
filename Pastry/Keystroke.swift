import Carbon.HIToolbox
import CoreGraphics
import IOKit.hidsystem

/// Synthesises the paste keystroke.
enum Keystroke {
    /// Sends ⌘V to whatever has keyboard focus. Returns whether the events
    /// were actually posted.
    ///
    /// Posted by key code, which is a **physical key position**, not the
    /// letter V. On QWERTY, QWERTZ and AZERTY that position carries V, and
    /// Apple's "Dvorak — QWERTY ⌘" layout reverts to QWERTY positions while
    /// Command is held, so those all paste correctly. On a layout that remaps
    /// the position without that variant — plain Dvorak, Colemak — this posts
    /// whatever letter sits there instead, and the paste does something else.
    ///
    /// Kept anyway because it is where Flycut landed: it previously looked up
    /// the key that produces "V" in the current layout and replaced that with
    /// the fixed key code to fix a layout bug (upstream `f36ca24`). A correct
    /// fix for the remaining case is a `UCKeyTranslate` reverse lookup with
    /// this as the fallback; see the spec's known limitations.
    ///
    /// The flags carry `NX_DEVICELCMDKEYMASK` alongside the command mask: that
    /// bit identifies the *left* command key, which some applications check
    /// for rather than the generic modifier.
    @MainActor
    @discardableResult
    static func commandV() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            Log.clipboard.error("could not create an event source; nothing was pasted")
            return false
        }
        let v = CGKeyCode(kVK_ANSI_V)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        else {
            Log.clipboard.error("could not build the key events; nothing was pasted")
            return false
        }

        // Assigning flags on both events also strips any modifier the user
        // happens to be holding, so a stray Shift cannot ride along.
        let flags = CGEventFlags(
            rawValue: CGEventFlags.maskCommand.rawValue | UInt64(NX_DEVICELCMDKEYMASK)
        )
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }
}

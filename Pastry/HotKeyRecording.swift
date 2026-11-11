import AppKit
import Carbon.HIToolbox

/// What a keystroke means while the key recorder is listening.
enum HotKeyRecordingOutcome: Equatable {
    case recorded(HotKeyCombination)
    /// Escape: the user backed out, and the old combination stands.
    case cancelled
    /// A key with no ⌘, ⌃ or ⌥ — said out loud rather than quietly stored.
    case needsAModifier
    /// A modifier on its own, which is how every recording starts.
    case ignored
}

/// Turns a keystroke into a recording outcome.
///
/// Takes the pieces of the event rather than an `NSEvent`, so every rule is a
/// plain test with no event loop involved — the same shape as `BezelKeyMap`.
enum HotKeyRecording {
    /// The only modifiers Carbon can register. Caps lock, fn and the
    /// numeric-pad flag ride along on ordinary events and would otherwise end
    /// up in a stored combination that could never be matched again.
    static let registrable: NSEvent.ModifierFlags = [.command, .control, .option, .shift]

    /// Key codes that are themselves modifiers, left and right.
    private static let modifierKeyCodes: Set<Int> = [
        kVK_Command, kVK_RightCommand, kVK_Shift, kVK_RightShift,
        kVK_Option, kVK_RightOption, kVK_Control, kVK_RightControl,
        kVK_Function, kVK_CapsLock,
    ]

    static func outcome(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags
    ) -> HotKeyRecordingOutcome {
        // Before anything else: Escape is how the user backs out, and it is
        // also the bezel's own dismiss key, so it is never recordable.
        if Int(keyCode) == kVK_Escape { return .cancelled }
        if modifierKeyCodes.contains(Int(keyCode)) { return .ignored }

        let combination = HotKeyCombination(
            keyCode: keyCode,
            modifiers: modifiers.intersection(registrable)
        )
        guard combination.isUsableAsHotKey else { return .needsAModifier }
        return .recorded(combination)
    }
}

import AppKit
import Carbon.HIToolbox

/// What a keystroke means while the key recorder is listening.
enum HotKeyRecordingOutcome: Equatable {
    case recorded(HotKeyCombination)
    /// Escape: the user backed out, and the old combination stands.
    case cancelled
    /// A key with no ⌘, ⌃ or ⌥ — said out loud rather than quietly stored.
    case needsAModifier
}

/// Turns a keystroke into a recording outcome.
///
/// Takes the pieces of the event rather than an `NSEvent`, so every rule is a
/// plain test with no event loop involved — the same shape as `BezelKeyMap`.
enum HotKeyRecording {
    /// There is no outcome for a modifier pressed on its own: AppKit reports
    /// those through `flagsChanged`, never `keyDown`, so one cannot reach
    /// here. `HotKeyCombination` drops the modifiers Carbon will not take.
    static func outcome(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags
    ) -> HotKeyRecordingOutcome {
        // Before anything else: Escape is how the user backs out, and it is
        // also the bezel's own dismiss key, so it is never recordable.
        if Int(keyCode) == kVK_Escape { return .cancelled }

        let combination = HotKeyCombination(keyCode: keyCode, modifiers: modifiers)
        guard combination.isUsableAsHotKey else { return .needsAModifier }
        return .recorded(combination)
    }
}

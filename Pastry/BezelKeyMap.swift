import AppKit
import Carbon.HIToolbox

/// What a keystroke means to the bezel.
enum BezelAction: Equatable {
    case older
    case newer
    case tenOlder
    case tenNewer
    case first
    case last
    /// Zero-based, so the `1` key is `.jump(0)`.
    case jump(Int)
    case paste
    case delete
    case cancel
    case preferences
    case ignored
}

/// Turns a keystroke into an action.
///
/// Takes the pieces of the event rather than an `NSEvent`, so every row of the
/// key table in the design spec is a plain test with no event loop involved.
enum BezelKeyMap {
    static func action(
        character: Character?,
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        hotKey: HotKeyCombination
    ) -> BezelAction {
        // Tapping the hotkey's own key with part of its combination still
        // held walks one clip older. Never newer: a "shift reverses it" row
        // cannot work for a combination that contains shift, which ⇧⌘V does,
        // and the taps made with the whole combination held never arrive here
        // at all — Carbon swallows the registered combination and calls the
        // hotkey handler instead. What reaches this window is the tap made
        // after letting go of part of it, ⌘V with shift released. ↑, ← and k
        // are how the user walks back the other way.
        if keyCode == hotKey.keyCode, !modifiers.intersection(hotKey.modifiers).isEmpty {
            return .older
        }

        switch Int(keyCode) {
        case kVK_DownArrow, kVK_RightArrow: return .older
        case kVK_UpArrow, kVK_LeftArrow: return .newer
        case kVK_PageDown: return .tenOlder
        case kVK_PageUp: return .tenNewer
        case kVK_Home: return .first
        case kVK_End: return .last
        case kVK_Return, kVK_ANSI_KeypadEnter: return .paste
        case kVK_Delete, kVK_ForwardDelete: return .delete
        case kVK_Escape: return .cancel
        default: break
        }

        // The keys below are matched by key code, not by the character the
        // event carries, because the bezel is used with the hotkey's
        // modifiers held: charactersIgnoringModifiers applies Shift, so while
        // the user holds ⌘⇧ the 1 key reports "!" and would match nothing.
        // Key codes are physical positions, the same layout dependence
        // already recorded for the paste keystroke in the design spec.
        // Matched by key code for the same reason as the digits below: with
        // the hotkey's shift held, the comma key reports "<".
        if Int(keyCode) == kVK_ANSI_Comma, modifiers.contains(.command) {
            return .preferences
        }

        if let digit = digit(forKeyCode: keyCode) {
            // Zero is the tenth clip, not the first: it sits after 9 on the
            // row.
            return .jump(digit == 0 ? 9 : digit - 1)
        }

        // Lowercased for the same reason: with shift held, j arrives as "J".
        guard let character else { return .ignored }
        switch character.lowercased() {
        case "j": return .older
        case "k": return .newer
        default: return .ignored
        }
    }

    /// The number on a key, from the number row or the keypad.
    private static func digit(forKeyCode keyCode: UInt16) -> Int? {
        digitsByKeyCode[Int(keyCode)]
    }

    private static let digitsByKeyCode: [Int: Int] = [
        kVK_ANSI_0: 0, kVK_ANSI_1: 1, kVK_ANSI_2: 2, kVK_ANSI_3: 3, kVK_ANSI_4: 4,
        kVK_ANSI_5: 5, kVK_ANSI_6: 6, kVK_ANSI_7: 7, kVK_ANSI_8: 8, kVK_ANSI_9: 9,
        kVK_ANSI_Keypad0: 0, kVK_ANSI_Keypad1: 1, kVK_ANSI_Keypad2: 2,
        kVK_ANSI_Keypad3: 3, kVK_ANSI_Keypad4: 4, kVK_ANSI_Keypad5: 5,
        kVK_ANSI_Keypad6: 6, kVK_ANSI_Keypad7: 7, kVK_ANSI_Keypad8: 8,
        kVK_ANSI_Keypad9: 9,
    ]
}

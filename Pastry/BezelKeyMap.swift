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
        hasCommand: Bool,
        hasShift: Bool,
        isHotKeyCode: Bool
    ) -> BezelAction {
        // Tapping the hotkey's own key while the modifiers are still held is
        // the primary interaction: ⌘⇧ down, V, V, V walks back through the
        // history. Shift reverses it.
        if isHotKeyCode, hasCommand {
            return hasShift ? .newer : .older
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

        guard let character else { return .ignored }

        if character == ",", hasCommand { return .preferences }

        switch character {
        case "j": return .older
        case "k": return .newer
        // Zero is the tenth clip, not the first: it sits after 9 on the row.
        case "0": return .jump(9)
        case "1"..."9":
            guard let digit = character.wholeNumberValue else { return .ignored }
            return .jump(digit - 1)
        default: return .ignored
        }
    }
}

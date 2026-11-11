import AppKit
import Carbon.HIToolbox
import Testing
@testable import Pastry

@Suite("BezelKeyMap")
struct BezelKeyMapTests {
    private let hotKey = HotKeyCombination.commandShiftV

    private func action(
        _ character: Character? = nil,
        keyCode: UInt16 = 0xFF,
        modifiers: NSEvent.ModifierFlags = []
    ) -> BezelAction {
        BezelKeyMap.action(
            character: character,
            keyCode: keyCode,
            modifiers: modifiers,
            hotKey: hotKey
        )
    }

    /// The primary interaction. The tap made with the whole combination held
    /// never reaches the bezel — Carbon claims the registered combination and
    /// calls the hotkey handler — so what arrives here is the tap made after
    /// letting go of part of it.
    @Test("the hotkey's key walks to older clips while part of the combination is held")
    func hotKeyWalksOlder() {
        #expect(action("v", keyCode: hotKey.keyCode, modifiers: [.command]) == .older)
        #expect(action("V", keyCode: hotKey.keyCode, modifiers: [.command, .shift]) == .older)
        #expect(action("V", keyCode: hotKey.keyCode, modifiers: [.shift]) == .older)
    }

    /// Otherwise typing the hotkey's letter with nothing held would walk the
    /// history, which is not what any other key does.
    @Test("the hotkey's key on its own does nothing")
    func bareHotKeyCharacterIgnored() {
        #expect(action("v", keyCode: hotKey.keyCode) == .ignored)
    }

    /// A combination the user may choose in feature 9. The key map must read
    /// it from the combination rather than from a copy of the default.
    @Test("another combination's key is what walks, not V")
    func honoursADifferentCombination() {
        let option = HotKeyCombination(
            keyCode: UInt16(kVK_ANSI_B),
            modifiers: [.option, .control]
        )
        #expect(
            BezelKeyMap.action(
                character: "b",
                keyCode: UInt16(kVK_ANSI_B),
                modifiers: [.option],
                hotKey: option
            ) == .older
        )
        #expect(
            BezelKeyMap.action(
                character: "v",
                keyCode: UInt16(kVK_ANSI_V),
                modifiers: [.option],
                hotKey: option
            ) == .ignored
        )
    }

    @Test("down and right go older", arguments: [
        UInt16(kVK_DownArrow), UInt16(kVK_RightArrow),
    ])
    func arrowsOlder(keyCode: UInt16) {
        #expect(action(keyCode: keyCode) == .older)
    }

    @Test("up and left go newer", arguments: [
        UInt16(kVK_UpArrow), UInt16(kVK_LeftArrow),
    ])
    func arrowsNewer(keyCode: UInt16) {
        #expect(action(keyCode: keyCode) == .newer)
    }

    @Test("j goes older and k goes newer")
    func viKeys() {
        #expect(action("j", keyCode: UInt16(kVK_ANSI_J)) == .older)
        #expect(action("k", keyCode: UInt16(kVK_ANSI_K)) == .newer)
    }

    /// The bezel is used with the hotkey's modifiers held down, and
    /// charactersIgnoringModifiers applies Shift: j arrives as "J". Matching
    /// the character as it comes would leave every one of these keys dead
    /// during the only interaction they exist for.
    @Test("j and k still work with the hotkey's modifiers held")
    func viKeysWithModifiersHeld() {
        let held: NSEvent.ModifierFlags = [.command, .shift]
        #expect(action("J", keyCode: UInt16(kVK_ANSI_J), modifiers: held) == .older)
        #expect(action("K", keyCode: UInt16(kVK_ANSI_K), modifiers: held) == .newer)
    }

    @Test("digits one to nine jump to that position")
    func digitsJump() {
        #expect(action("1", keyCode: UInt16(kVK_ANSI_1)) == .jump(0))
        #expect(action("5", keyCode: UInt16(kVK_ANSI_5)) == .jump(4))
        #expect(action("9", keyCode: UInt16(kVK_ANSI_9)) == .jump(8))
    }

    /// With shift held the number row reports punctuation — "!" for 1 — so
    /// the digits are matched by key code.
    @Test("the number row still jumps with the hotkey's modifiers held")
    func digitsJumpWithModifiersHeld() {
        let held: NSEvent.ModifierFlags = [.command, .shift]
        #expect(action("!", keyCode: UInt16(kVK_ANSI_1), modifiers: held) == .jump(0))
        #expect(action("%", keyCode: UInt16(kVK_ANSI_5), modifiers: held) == .jump(4))
        #expect(action(")", keyCode: UInt16(kVK_ANSI_0), modifiers: held) == .jump(9))
    }

    @Test("the keypad jumps too")
    func keypadDigitsJump() {
        #expect(action("1", keyCode: UInt16(kVK_ANSI_Keypad1)) == .jump(0))
        #expect(action("0", keyCode: UInt16(kVK_ANSI_Keypad0)) == .jump(9))
    }

    /// Zero is the tenth, not the first — it sits after 9 on the keyboard.
    @Test("zero jumps to the tenth clip")
    func zeroJumpsToTenth() {
        #expect(action("0", keyCode: UInt16(kVK_ANSI_0)) == .jump(9))
    }

    @Test("home and end go to the ends")
    func homeAndEnd() {
        #expect(action(keyCode: UInt16(kVK_Home)) == .first)
        #expect(action(keyCode: UInt16(kVK_End)) == .last)
    }

    @Test("page up and page down move ten at a time")
    func pageKeys() {
        #expect(action(keyCode: UInt16(kVK_PageUp)) == .tenNewer)
        #expect(action(keyCode: UInt16(kVK_PageDown)) == .tenOlder)
    }

    @Test("return and the keypad's enter paste", arguments: [
        UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter),
    ])
    func returnPastes(keyCode: UInt16) {
        #expect(action(keyCode: keyCode) == .paste)
    }

    /// Return is pressed with the hotkey's modifiers still held, so it has to
    /// win over them rather than be read as a modified keystroke.
    @Test("return pastes with the hotkey's modifiers held")
    func returnPastesWithModifiersHeld() {
        #expect(action(keyCode: UInt16(kVK_Return), modifiers: [.command, .shift]) == .paste)
    }

    @Test("delete and backspace remove the shown clip", arguments: [
        UInt16(kVK_Delete), UInt16(kVK_ForwardDelete),
    ])
    func deleteRemoves(keyCode: UInt16) {
        #expect(action(keyCode: keyCode) == .delete)
    }

    @Test("escape dismisses")
    func escapeCancels() {
        #expect(action(keyCode: UInt16(kVK_Escape)) == .cancel)
    }

    @Test("command-comma opens Preferences")
    func commandCommaOpensPreferences() {
        #expect(action(",", keyCode: UInt16(kVK_ANSI_Comma), modifiers: [.command]) == .preferences)
    }

    /// With the hotkey's shift held the comma key reports "<", which is why
    /// it is matched by key code like the digits.
    @Test("command-comma still works with the hotkey's modifiers held")
    func commandCommaWithModifiersHeld() {
        #expect(
            action("<", keyCode: UInt16(kVK_ANSI_Comma), modifiers: [.command, .shift])
                == .preferences
        )
    }

    /// Without command it is just a comma, and the bezel has no text field.
    @Test("a bare comma does nothing")
    func bareCommaIgnored() {
        #expect(action(",", keyCode: UInt16(kVK_ANSI_Comma)) == .ignored)
    }

    @Test("anything else is ignored")
    func otherKeysIgnored() {
        #expect(action("q", keyCode: UInt16(kVK_ANSI_Q)) == .ignored)
        #expect(action(keyCode: 0x42) == .ignored)
    }
}

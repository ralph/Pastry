import Carbon.HIToolbox
import Testing
@testable import Pastry

@Suite("BezelKeyMap")
struct BezelKeyMapTests {
    private func action(
        _ character: Character? = nil,
        keyCode: UInt16 = 0xFF,
        command: Bool = false,
        shift: Bool = false,
        isHotKey: Bool = false
    ) -> BezelAction {
        BezelKeyMap.action(
            character: character,
            keyCode: keyCode,
            hasCommand: command,
            hasShift: shift,
            isHotKeyCode: isHotKey
        )
    }

    // The primary interaction: holding the modifiers and tapping the hotkey's
    // own key walks backwards through the history.
    @Test("the hotkey's key walks to older clips")
    func hotKeyWalksOlder() {
        #expect(action(keyCode: UInt16(kVK_ANSI_V), command: true, isHotKey: true) == .older)
    }

    @Test("the hotkey's key with shift walks back towards newer clips")
    func hotKeyWithShiftWalksNewer() {
        #expect(
            action(keyCode: UInt16(kVK_ANSI_V), command: true, shift: true, isHotKey: true) == .newer
        )
    }

    @Test("down, right and j go older", arguments: [
        UInt16(kVK_DownArrow), UInt16(kVK_RightArrow),
    ])
    func arrowsOlder(keyCode: UInt16) {
        #expect(action(keyCode: keyCode) == .older)
    }

    @Test("up, left and k go newer", arguments: [
        UInt16(kVK_UpArrow), UInt16(kVK_LeftArrow),
    ])
    func arrowsNewer(keyCode: UInt16) {
        #expect(action(keyCode: keyCode) == .newer)
    }

    @Test("j goes older and k goes newer")
    func viKeys() {
        #expect(action("j") == .older)
        #expect(action("k") == .newer)
    }

    @Test("digits one to nine jump to that position")
    func digitsJump() {
        #expect(action("1") == .jump(0))
        #expect(action("5") == .jump(4))
        #expect(action("9") == .jump(8))
    }

    /// Zero is the tenth, not the first — it sits after 9 on the keyboard.
    @Test("zero jumps to the tenth clip")
    func zeroJumpsToTenth() {
        #expect(action("0") == .jump(9))
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

    @Test("return pastes")
    func returnPastes() {
        #expect(action(keyCode: UInt16(kVK_Return)) == .paste)
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

    @Test("command-comma opens preferences")
    func commandCommaOpensPreferences() {
        #expect(action(",", command: true) == .preferences)
    }

    /// Without command it is just a comma, and the bezel has no text field.
    @Test("a bare comma does nothing")
    func bareCommaIgnored() {
        #expect(action(",") == .ignored)
    }

    @Test("anything else is ignored")
    func otherKeysIgnored() {
        #expect(action("q") == .ignored)
        #expect(action(keyCode: 0x42) == .ignored)
    }
}

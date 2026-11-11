import AppKit
import Carbon.HIToolbox
import Testing
@testable import Pastry

@Suite("HotKeyCombination")
@MainActor
struct HotKeyCombinationTests {
    @Test("round trips through defaults")
    func roundTrip() {
        let defaults = makeTestDefaults()
        let combination = HotKeyCombination(
            keyCode: UInt16(kVK_ANSI_B),
            modifiers: [.command, .option]
        )
        combination.write(to: defaults)
        #expect(HotKeyCombination(defaults: defaults) == combination)
    }

    @Test("reports nothing stored")
    func nothingStored() {
        #expect(HotKeyCombination(defaults: makeTestDefaults()) == nil)
    }

    /// These are ordinary defaults keys; anything can have written them, and a
    /// combination with no real modifier would fire on an ordinary keystroke.
    @Test("refuses a stored combination that is not usable")
    func refusesUnusableStoredValue() {
        let defaults = makeTestDefaults()
        HotKeyCombination(keyCode: UInt16(kVK_ANSI_V), modifiers: [.shift])
            .write(to: defaults)
        #expect(HotKeyCombination(defaults: defaults) == nil)
    }

    /// Half a combination is not one: a key code with no modifiers beside it
    /// would read as an unmodified hotkey.
    @Test("refuses a half-written combination")
    func refusesHalfWritten() {
        let defaults = makeTestDefaults()
        defaults.set(Int(kVK_ANSI_V), forKey: "hotKeyKeyCode")
        #expect(HotKeyCombination(defaults: defaults) == nil)
    }

    /// The filter lives in the initialiser, so no combination anywhere can
    /// carry a modifier Carbon will not register — however it was built.
    /// With caps lock kept, the bezel's release check would never see the
    /// modifiers go empty and it would never paste.
    @Test("drops modifiers Carbon cannot register, however it is built")
    func filtersOnConstruction() {
        let built = HotKeyCombination(
            keyCode: UInt16(kVK_ANSI_V),
            modifiers: [.command, .capsLock, .function, .numericPad]
        )
        #expect(built.modifiers == [.command])

        let defaults = makeTestDefaults()
        defaults.set(Int(kVK_ANSI_V), forKey: "hotKeyKeyCode")
        defaults.set(
            Int(bitPattern: NSEvent.ModifierFlags([.command, .capsLock]).rawValue),
            forKey: "hotKeyModifiers"
        )
        #expect(HotKeyCombination(defaults: defaults)?.modifiers == [.command])
    }

    @Test("needs one of command, control or option", arguments: [
        (NSEvent.ModifierFlags([.command]), true),
        (NSEvent.ModifierFlags([.control]), true),
        (NSEvent.ModifierFlags([.option]), true),
        (NSEvent.ModifierFlags([.command, .shift]), true),
        (NSEvent.ModifierFlags([.shift]), false),
        (NSEvent.ModifierFlags([]), false),
        (NSEvent.ModifierFlags([.capsLock]), false),
    ])
    func usability(modifiers: NSEvent.ModifierFlags, usable: Bool) {
        let combination = HotKeyCombination(keyCode: UInt16(kVK_ANSI_V), modifiers: modifiers)
        #expect(combination.isUsableAsHotKey == usable)
    }

    /// The order every Mac menu uses, so the string reads the way the user
    /// has seen a shortcut written their whole life.
    @Test("writes modifiers in the conventional order")
    func modifierOrder() {
        let all = HotKeyCombination(
            keyCode: UInt16(kVK_ANSI_V),
            modifiers: [.command, .shift, .option, .control]
        )
        #expect(all.displayString == "⌃⌥⇧⌘V")
        #expect(HotKeyCombination.commandShiftV.displayString == "⇧⌘V")
    }

    @Test("names keys that have no character", arguments: [
        (kVK_Space, "Space"), (kVK_Return, "Return"), (kVK_Escape, "Escape"),
        (kVK_LeftArrow, "←"), (kVK_F1, "F1"), (kVK_Delete, "⌫"),
        (kVK_PageUp, "Page Up"),
    ])
    func specialKeyNames(keyCode: Int, name: String) {
        let combination = HotKeyCombination(
            keyCode: UInt16(keyCode),
            modifiers: [.command]
        )
        #expect(combination.displayString == "⌘" + name)
    }

    /// A key code with no name and no character still has to produce
    /// something rather than an empty button.
    @Test("falls back to the key code when a key cannot be named")
    func unnameableKey() {
        let combination = HotKeyCombination(keyCode: 0xFE, modifiers: [.command])
        #expect(combination.displayString.hasPrefix("⌘"))
        #expect(combination.displayString.count > 1)
    }
}

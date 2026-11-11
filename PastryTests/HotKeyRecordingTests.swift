import AppKit
import Carbon.HIToolbox
import Testing
@testable import Pastry

@Suite("HotKeyRecording")
struct HotKeyRecordingTests {
    private func outcome(
        _ keyCode: Int,
        _ modifiers: NSEvent.ModifierFlags = []
    ) -> HotKeyRecordingOutcome {
        HotKeyRecording.outcome(keyCode: UInt16(keyCode), modifiers: modifiers)
    }

    @Test("records a key held with a real modifier")
    func recordsACombination() {
        #expect(
            outcome(kVK_ANSI_B, [.command, .option])
                == .recorded(HotKeyCombination(keyCode: UInt16(kVK_ANSI_B),
                                               modifiers: [.command, .option]))
        )
    }

    /// Escape is how the user backs out, and it is the bezel's dismiss key.
    @Test("escape cancels instead of being recorded")
    func escapeCancels() {
        #expect(outcome(kVK_Escape) == .cancelled)
        #expect(outcome(kVK_Escape, [.command]) == .cancelled)
    }

    /// ⇧V is a capital V. Such a hotkey would fire whenever the user typed
    /// that letter and they could never type it again.
    @Test("refuses a combination with no command, control or option")
    func refusesWithoutARealModifier() {
        #expect(outcome(kVK_ANSI_V) == .needsAModifier)
        #expect(outcome(kVK_ANSI_V, [.shift]) == .needsAModifier)
    }

    /// Caps lock, fn and the numeric-pad flag ride along on ordinary events.
    /// Stored, they would make a combination Carbon could never match again.
    @Test("keeps only the modifiers Carbon can register")
    func filtersModifiers() {
        #expect(
            outcome(kVK_ANSI_B, [.command, .capsLock, .numericPad, .function])
                == .recorded(HotKeyCombination(keyCode: UInt16(kVK_ANSI_B),
                                               modifiers: [.command]))
        )
    }

    /// Shift is registrable and may join a real modifier — it just cannot
    /// stand alone.
    @Test("keeps shift when it rides with a real modifier")
    func keepsShiftAlongside() {
        #expect(
            outcome(kVK_ANSI_V, [.command, .shift])
                == .recorded(.commandShiftV)
        )
    }

    /// A function key carries no character, so nothing else qualifies it —
    /// but it is still a key, and ⌃F5 is a reasonable thing to want.
    @Test("records a function key with a modifier")
    func recordsAFunctionKey() {
        #expect(
            outcome(kVK_F5, [.control])
                == .recorded(HotKeyCombination(keyCode: UInt16(kVK_F5), modifiers: [.control]))
        )
    }
}

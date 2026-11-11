import AppKit
import Carbon.HIToolbox
import Foundation
import Testing
@testable import Pastry

@Suite("Preferences")
@MainActor
struct PreferencesTests {
    @Test("starts at the documented defaults")
    func defaultsAreTheSpecifiedOnes() {
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
        #expect(preferences.rememberCount == 40)
        #expect(preferences.displayCount == 30)
    }

    @Test("remembers what it was set to")
    func persistsAcrossInstances() {
        let defaults = makeTestDefaults()
        let first = Preferences(defaults: defaults, loginItem: FakeLoginItem())
        first.rememberCount = 12
        first.displayCount = 7

        let second = Preferences(defaults: defaults, loginItem: FakeLoginItem())
        #expect(second.rememberCount == 12)
        #expect(second.displayCount == 7)
    }

    /// A stepper cannot produce these, but `defaults write` from the command
    /// line can, and so can a later caller.
    @Test("clamps a count to the allowed range", arguments: [
        (0, 1), (-5, 1), (100, 99), (1, 1), (99, 99),
    ])
    func clampsCounts(given: Int, expected: Int) {
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
        preferences.rememberCount = given
        preferences.displayCount = given
        #expect(preferences.rememberCount == expected)
        #expect(preferences.displayCount == expected)
    }

    @Test("clamps a stored value that is out of range")
    func clampsWhatItReads() {
        let defaults = makeTestDefaults()
        defaults.set(10_000, forKey: "rememberCount")
        defaults.set(0, forKey: "displayCount")
        let preferences = Preferences(defaults: defaults, loginItem: FakeLoginItem())
        #expect(preferences.rememberCount == 99)
        #expect(preferences.displayCount == 1)
    }

    @Test("starts at the default hotkey")
    func defaultHotKey() {
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
        #expect(preferences.hotKey == .commandShiftV)
        #expect(!preferences.hotKeyIsUnavailable)
    }

    @Test("remembers a recorded hotkey")
    func persistsTheHotKey() {
        let defaults = makeTestDefaults()
        let chosen = HotKeyCombination(keyCode: UInt16(kVK_ANSI_B), modifiers: [.control, .option])

        let first = Preferences(defaults: defaults, loginItem: FakeLoginItem())
        first.hotKey = chosen

        let second = Preferences(defaults: defaults, loginItem: FakeLoginItem())
        #expect(second.hotKey == chosen)
    }

    @Test("announces a new hotkey so it can be registered")
    func announcesTheHotKey() {
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
        var changes = 0
        preferences.onChange = { changes += 1 }
        preferences.hotKey = HotKeyCombination(keyCode: UInt16(kVK_ANSI_B), modifiers: [.command])
        #expect(changes == 1)
    }

    /// Re-registering a Carbon hotkey for a value that did not change would
    /// be absurd, and the apply path runs on every stepper tick in General.
    @Test("stays silent when the hotkey is set to what it already is")
    func silentOnAnUnchangedHotKey() {
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
        var changes = 0
        preferences.onChange = { changes += 1 }
        let same = preferences.hotKey
        preferences.hotKey = same
        #expect(changes == 0)
    }

    /// The app is never left without a working hotkey: a refusal puts the
    /// old one back and says so.
    @Test("reverts and reports a combination another app already owns")
    func revertsARefusedHotKey() {
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
        let previous = preferences.hotKey
        preferences.hotKey = HotKeyCombination(keyCode: UInt16(kVK_ANSI_B), modifiers: [.command])

        preferences.reportHotKeyRefused()

        #expect(preferences.hotKey == previous)
        #expect(preferences.hotKeyIsUnavailable)
    }

    /// At launch nothing has been replaced yet, so there is nothing to go
    /// back to — Pastry simply has no hotkey, and must not pretend the
    /// refused one is in use by reverting to it.
    @Test("reports a refusal at launch without inventing a previous one")
    func refusalWithNothingToRevertTo() {
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
        let atLaunch = preferences.hotKey

        preferences.reportHotKeyRefused()

        #expect(preferences.hotKey == atLaunch)
        #expect(preferences.hotKeyIsUnavailable)
    }

    /// Recording the same combination again is how a user retries one that
    /// was refused, after quitting whatever had taken it. An early return on
    /// the unchanged value used to swallow the retry and leave the warning
    /// standing with no way out but recording something else first.
    @Test("lets the same combination be retried after a refusal")
    func retriesTheSameCombination() {
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
        preferences.reportHotKeyRefused()
        #expect(preferences.hotKeyIsUnavailable)

        var changes = 0
        preferences.onChange = { changes += 1 }
        preferences.hotKey = preferences.hotKey

        #expect(!preferences.hotKeyIsUnavailable)
        // The announcement is the retry: without it the warning clears and
        // nothing is ever registered.
        #expect(changes == 1)
    }

    /// The reverted combination has to be what a relaunch reads back, or the
    /// app would come up registering the one that was refused.
    @Test("persists the combination it reverted to")
    func persistsTheRevertedHotKey() {
        let defaults = makeTestDefaults()
        let preferences = Preferences(defaults: defaults, loginItem: FakeLoginItem())
        let previous = preferences.hotKey
        preferences.hotKey = HotKeyCombination(keyCode: UInt16(kVK_ANSI_B), modifiers: [.command])
        preferences.reportHotKeyRefused()

        let relaunched = Preferences(defaults: defaults, loginItem: FakeLoginItem())
        #expect(relaunched.hotKey == previous)
    }

    /// Otherwise the warning would outlive the combination it was about.
    @Test("clears the warning once a different combination is recorded")
    func clearsTheWarning() {
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
        preferences.reportHotKeyRefused()
        #expect(preferences.hotKeyIsUnavailable)

        preferences.hotKey = HotKeyCombination(keyCode: UInt16(kVK_ANSI_B), modifiers: [.command])
        #expect(!preferences.hotKeyIsUnavailable)
    }

    @Test("announces a change so the app can apply it")
    func announcesChanges() {
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
        var changes = 0
        preferences.onChange = { changes += 1 }

        preferences.rememberCount = 10
        preferences.displayCount = 5
        #expect(changes == 2)
    }

    /// Otherwise holding down a stepper would re-trim the history and
    /// schedule a write of it on every repeat that changed nothing.
    @Test("stays silent when a value is set to what it already is")
    func staysSilentWhenNothingChanges() {
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
        var changes = 0
        preferences.onChange = { changes += 1 }

        let remember = preferences.rememberCount
        let display = preferences.displayCount
        preferences.rememberCount = remember
        preferences.displayCount = display
        #expect(changes == 0)
    }

    /// The clamp must not swallow the change it clamped: setting 1000 from 40
    /// really is a change to 99, and the history has to be trimmed for it.
    @Test("announces a change that arrived out of range")
    func announcesAClampedChange() {
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
        var changes = 0
        preferences.onChange = { changes += 1 }

        preferences.rememberCount = 1_000
        #expect(preferences.rememberCount == 99)
        #expect(changes == 1)
    }

    /// What the app does in `onChange` is read the value back. If the write
    /// had not landed by then, every settings change would be applied one
    /// step late — the store would be trimmed to the count before last.
    @Test("has the new value in place before it announces it")
    func announcesAfterTheValueLands() {
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
        var seen: [Int] = []
        preferences.onChange = { seen.append(preferences.rememberCount) }

        preferences.rememberCount = 10
        preferences.rememberCount = 7
        #expect(seen == [10, 7])
    }

    /// Compared after clamping, not before. Otherwise holding a stepper at
    /// its limit would re-trim the history and schedule a disk write on
    /// every tick that moved nothing.
    @Test("stays silent when an out-of-range value clamps to what it already is")
    func staysSilentWhenTheClampChangesNothing() {
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
        preferences.rememberCount = 99
        var changes = 0
        preferences.onChange = { changes += 1 }

        preferences.rememberCount = 1_000
        preferences.rememberCount = 500
        #expect(preferences.rememberCount == 99)
        #expect(changes == 0)
    }
}

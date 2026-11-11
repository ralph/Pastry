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

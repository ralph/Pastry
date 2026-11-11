import Foundation
import Testing
@testable import Pastry

@Suite("Launch at login")
@MainActor
struct LoginItemTests {
    @Test("turns itself on the first time Pastry runs")
    func onByDefault() {
        let item = FakeLoginItem()
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: item)
        preferences.applyDefaultLoginItemOnce()
        #expect(item.changes == [true])
        #expect(preferences.launchAtLogin)
    }

    /// The whole point of the stored marker: a user who turns it off has to
    /// find it still off at the next launch.
    @Test("does not turn itself back on after the user turned it off")
    func respectsTheUsersChoice() {
        let defaults = makeTestDefaults()
        let item = FakeLoginItem()

        let first = Preferences(defaults: defaults, loginItem: item)
        first.applyDefaultLoginItemOnce()
        first.launchAtLogin = false

        let second = Preferences(defaults: defaults, loginItem: item)
        second.applyDefaultLoginItemOnce()

        #expect(item.changes == [true, false])
        #expect(!second.launchAtLogin)
    }

    /// Applying the default is what every launch calls, so it has to be
    /// harmless to call repeatedly within one run too.
    @Test("applies the default only once however often it is asked")
    func appliesOnlyOnce() {
        let item = FakeLoginItem()
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: item)
        preferences.applyDefaultLoginItemOnce()
        preferences.applyDefaultLoginItemOnce()
        preferences.applyDefaultLoginItemOnce()
        #expect(item.changes == [true])
    }

    /// Cached, it would disagree with the system the moment the user changed
    /// it in System Settings.
    @Test("reports what the system says, not what it was last told")
    func readsTheSystemState() {
        let item = FakeLoginItem()
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: item)

        item.isEnabled = true
        #expect(preferences.launchAtLogin)
        item.isEnabled = false
        #expect(!preferences.launchAtLogin)
    }

    /// macOS answers `register()` with "waiting for approval" rather than an
    /// error, and nothing happens at login until the user allows it — so the
    /// window has to be able to say so.
    @Test("surfaces a registration still waiting for approval")
    func surfacesApproval() {
        let item = FakeLoginItem()
        item.needsApproval = true
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: item)
        #expect(preferences.loginItemNeedsApproval)
    }

    @Test("can send the user to System Settings")
    func opensSystemSettings() {
        let item = FakeLoginItem()
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: item)
        preferences.openLoginItemSettings()
        #expect(item.openedSystemSettings)
    }
}

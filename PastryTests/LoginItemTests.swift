import Foundation
import Testing
@testable import Pastry

/// A login item that refuses to turn on, as macOS does when the user has
/// blocked it.
@MainActor
private final class RefusingLoginItem: LoginItem {
    var isEnabled = false
    var needsApproval = false
    func setEnabled(_ enabled: Bool) {}
    func openSystemSettings() {}
}

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

    /// The value is a mirror of the system's, not a record of what Pastry
    /// last asked for — the user can change it in System Settings while
    /// Pastry is not looking, and showing the window refreshes it.
    @Test("picks up a change made outside Pastry when refreshed")
    func refreshesFromTheSystem() {
        let item = FakeLoginItem()
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: item)
        #expect(!preferences.launchAtLogin)

        item.isEnabled = true
        preferences.refreshLoginItemState()
        #expect(preferences.launchAtLogin)

        item.isEnabled = false
        preferences.refreshLoginItemState()
        #expect(!preferences.launchAtLogin)
    }

    /// A toggle that stayed on after the request was refused would claim
    /// something that is not true.
    @Test("falls back to the system's answer when the request is refused")
    func followsARefusedRequest() {
        let item = RefusingLoginItem()
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: item)

        preferences.launchAtLogin = true
        #expect(!preferences.launchAtLogin)
    }

    /// Setting it to what it already is must not go near the system: each
    /// call is a synchronous round trip of about a millisecond.
    @Test("asks the system nothing when the value is unchanged")
    func silentWhenUnchanged() {
        let item = FakeLoginItem()
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: item)
        preferences.launchAtLogin = false
        #expect(item.changes.isEmpty)
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

    /// The row that says so appears on first run, after register() has been
    /// called — so it has to come from the refresh, not only from init.
    @Test("surfaces approval that only became necessary after registering")
    func surfacesApprovalAfterRegistering() {
        let item = FakeLoginItem()
        let preferences = Preferences(defaults: makeTestDefaults(), loginItem: item)
        #expect(!preferences.loginItemNeedsApproval)

        item.needsApproval = true
        preferences.applyDefaultLoginItemOnce()
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

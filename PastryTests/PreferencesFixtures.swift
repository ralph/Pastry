import Foundation
@testable import Pastry

/// A login item that only records what it was told.
///
/// No test may reach `SMAppService`: registering a real login item writes to
/// the user's own System Settings and outlives the test run.
///
/// Shared by more than one suite, which is why it lives here rather than
/// `private` inside one of them, as `FakeClipboard` and `FakeHistoryFile` do.
@MainActor
final class FakeLoginItem: LoginItem {
    var isEnabled = false
    var needsApproval = false
    private(set) var changes: [Bool] = []
    private(set) var openedSystemSettings = false

    func setEnabled(_ enabled: Bool) {
        changes.append(enabled)
        isEnabled = enabled
    }

    func openSystemSettings() { openedSystemSettings = true }
}

/// A defaults suite of its own per call, so nothing reaches the real defaults
/// and one test cannot see another's writes.
@MainActor
func makeTestDefaults() -> UserDefaults {
    UserDefaults(suiteName: "de.rvdh.Pastry.tests.\(UUID().uuidString)")!
}

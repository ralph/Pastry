import Foundation
import Observation

/// Everything the user can change.
///
/// The counts live in `UserDefaults`. Launch at login does not: the system
/// owns that state, and the user can change it from System Settings without
/// Pastry running.
@MainActor
@Observable
final class Preferences {
    /// Below one, a clipboard manager remembers nothing, which is a way to
    /// lose work rather than a setting. Ninety-nine is Flycut's ceiling.
    static let countRange = 1...99

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let loginItem: LoginItem

    /// Called when a stored value actually changed, so the app can apply it.
    @ObservationIgnored var onChange: (() -> Void)?

    var rememberCount: Int {
        didSet {
            let clamped = Self.clamp(rememberCount)
            // Re-enters this observer with the in-range value, which then
            // falls through to the persist below. Only reachable from a
            // defaults write or a programmatic set — the stepper cannot
            // leave the range.
            guard clamped == rememberCount else {
                rememberCount = clamped
                return
            }
            guard rememberCount != oldValue else { return }
            defaults.set(rememberCount, forKey: Key.rememberCount)
            onChange?()
        }
    }

    var displayCount: Int {
        didSet {
            let clamped = Self.clamp(displayCount)
            guard clamped == displayCount else {
                displayCount = clamped
                return
            }
            guard displayCount != oldValue else { return }
            defaults.set(displayCount, forKey: Key.displayCount)
            onChange?()
        }
    }

    var launchAtLogin: Bool {
        get { loginItem.isEnabled }
        set { loginItem.setEnabled(newValue) }
    }

    var loginItemNeedsApproval: Bool { loginItem.needsApproval }

    init(defaults: UserDefaults = .standard, loginItem: LoginItem) {
        self.defaults = defaults
        self.loginItem = loginItem
        defaults.register(defaults: [
            Key.rememberCount: 40,
            Key.displayCount: 30,
        ])
        // Clamped on the way in as well: these are ordinary defaults keys and
        // anything at all can have written them.
        rememberCount = Self.clamp(defaults.integer(forKey: Key.rememberCount))
        displayCount = Self.clamp(defaults.integer(forKey: Key.displayCount))
    }

    /// Turns launch at login on the first time Pastry runs, and never again.
    ///
    /// Without the stored marker, a user who turned it off would find it back
    /// on at the next launch.
    func applyDefaultLoginItemOnce() {
        guard !defaults.bool(forKey: Key.appliedDefaultLoginItem) else { return }
        defaults.set(true, forKey: Key.appliedDefaultLoginItem)
        loginItem.setEnabled(true)
    }

    func openLoginItemSettings() { loginItem.openSystemSettings() }

    private static func clamp(_ value: Int) -> Int {
        min(max(value, countRange.lowerBound), countRange.upperBound)
    }

    private enum Key {
        static let rememberCount = "rememberCount"
        static let displayCount = "displayCount"
        static let appliedDefaultLoginItem = "appliedDefaultLoginItem"
    }
}

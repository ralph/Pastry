import Foundation
import Observation

/// Everything the user can change.
///
/// The counts live in `UserDefaults`. Launch at login does not: the system
/// owns that state, and the user can change it from System Settings without
/// Pastry running — so what is kept here is a mirror, refreshed when there is
/// a reason to think it has moved.
@MainActor
@Observable
final class Preferences {
    /// Below one, a clipboard manager remembers nothing, which is a way to
    /// lose work rather than a setting. Ninety-nine is Flycut's ceiling.
    static let countRange = 1...99
    static let defaultRememberCount = 40
    static let defaultDisplayCount = 30

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let loginItem: LoginItem

    /// Called when a stored value actually changed, so the app can apply it.
    ///
    /// Alongside `@Observable` rather than instead of it: SwiftUI learns
    /// through observation, but the AppKit consumers — the store, the menu,
    /// and feature 9's hotkey registration — are not in an update graph and
    /// have to be told.
    @ObservationIgnored var onChange: (() -> Void)?

    // Observation instruments stored properties only, so the public values
    // below are computed over these. Their names must not begin with an
    // underscore: that is where the macro puts its own backing storage.
    private var storedRememberCount: Int
    private var storedDisplayCount: Int
    private var storedLaunchAtLogin: Bool
    private var storedHotKey: HotKeyCombination

    var rememberCount: Int {
        get { storedRememberCount }
        set { assign(newValue, to: \.storedRememberCount, key: Key.rememberCount) }
    }

    var displayCount: Int {
        get { storedDisplayCount }
        set { assign(newValue, to: \.storedDisplayCount, key: Key.displayCount) }
    }

    /// Whether Pastry starts at login.
    ///
    /// Reading this gives the mirror, not the system. Asking the system is a
    /// synchronous round trip to `smd` of about a millisecond, which SwiftUI
    /// would pay several times per redraw — and a computed property over the
    /// service would register no observation dependency at all, so the toggle
    /// would never redraw when its own value changed.
    var launchAtLogin: Bool {
        get { storedLaunchAtLogin }
        set {
            guard newValue != storedLaunchAtLogin else { return }
            loginItem.setEnabled(newValue)
            // Read back rather than assumed: the request can be refused, or
            // answered with "waiting for approval", and the toggle has to
            // show what actually happened.
            refreshLoginItemState()
        }
    }

    /// macOS answers `register()` with this rather than an error, and nothing
    /// happens at login until the user allows it.
    private(set) var loginItemNeedsApproval: Bool

    /// The combination that summons the bezel.
    var hotKey: HotKeyCombination {
        get { storedHotKey }
        set {
            // Recording the same combination again is how a user retries one
            // that was refused, after quitting whatever had taken it. That
            // has to announce a change even though the value is unchanged,
            // or the early return swallows the retry: the warning would
            // clear and nothing would be registered. Only a refusal makes an
            // unchanged value worth announcing.
            let retryingARefusal = hotKeyIsUnavailable
            hotKeyIsUnavailable = false
            guard newValue != storedHotKey || retryingARefusal else { return }

            // Only a real change has something to go back to.
            if newValue != storedHotKey { previousHotKey = storedHotKey }
            storedHotKey = newValue
            newValue.write(to: defaults)
            onChange?()
        }
    }

    /// True when the combination the user asked for was already owned by
    /// another application.
    private(set) var hotKeyIsUnavailable = false

    /// The last combination that was replaced, so a refusal can go back to
    /// it. Nil until one is, which is the launch case: there is nothing to
    /// go back to, and Pastry simply has no hotkey.
    @ObservationIgnored private var previousHotKey: HotKeyCombination?

    init(defaults: UserDefaults = .standard, loginItem: LoginItem) {
        self.defaults = defaults
        self.loginItem = loginItem
        defaults.register(defaults: [
            Key.rememberCount: Self.defaultRememberCount,
            Key.displayCount: Self.defaultDisplayCount,
        ])
        // Clamped on the way in as well as on the way out: these are ordinary
        // defaults keys and anything at all can have written them.
        storedRememberCount = Self.clamp(defaults.integer(forKey: Key.rememberCount))
        storedDisplayCount = Self.clamp(defaults.integer(forKey: Key.displayCount))
        storedLaunchAtLogin = loginItem.isEnabled
        loginItemNeedsApproval = loginItem.needsApproval
        storedHotKey = HotKeyCombination(defaults: defaults) ?? .commandShiftV
    }

    /// Records that Carbon refused the combination, and puts back the one
    /// that was working before it — if there was one.
    ///
    /// Takes no argument: the only moment a previous value exists is inside
    /// this object's own setter, one line before it is overwritten, so asking
    /// a caller for it buys nothing and lets a caller with none to give pass
    /// the refused value back as though it were the good one.
    ///
    /// Assigned through the backing property rather than `hotKey`, which
    /// would clear the very flag being set and announce a change that is
    /// really the undoing of one.
    func reportHotKeyRefused() {
        hotKeyIsUnavailable = true
        guard let previousHotKey else { return }
        storedHotKey = previousHotKey
        previousHotKey.write(to: defaults)
        self.previousHotKey = nil
    }

    /// Reads the system's launch-at-login state back into the mirror.
    ///
    /// Called when the Settings window is shown, because the user may have
    /// changed it in System Settings while Pastry was not looking.
    func refreshLoginItemState() {
        storedLaunchAtLogin = loginItem.isEnabled
        loginItemNeedsApproval = loginItem.needsApproval
    }

    /// Turns launch at login on the first time Pastry runs, and never again.
    ///
    /// Without the stored marker, a user who turned it off would find it back
    /// on at the next launch.
    func applyDefaultLoginItemOnce() {
        guard !defaults.bool(forKey: Key.appliedDefaultLoginItem) else { return }
        defaults.set(true, forKey: Key.appliedDefaultLoginItem)
        loginItem.setEnabled(true)
        refreshLoginItemState()
    }

    func openLoginItemSettings() { loginItem.openSystemSettings() }

    /// The only way a count changes: clamp, store, persist, announce.
    ///
    /// Clamping here rather than at the call site because the call sites that
    /// can produce an out-of-range value are `defaults write` from a shell and
    /// a later caller — the stepper is already bound to the range.
    ///
    /// Takes a key path rather than the property `inout`. An `inout` write
    /// back only lands when this returns, so `onChange` would run while the
    /// property still held the old value — and because the handler reads it
    /// back, the two overlapping accesses trap: "Fatal access conflict
    /// detected", on every settings change. A key path writes through at the
    /// assignment, before anything is announced.
    private func assign(
        _ newValue: Int,
        to keyPath: ReferenceWritableKeyPath<Preferences, Int>,
        key: String
    ) {
        let clamped = Self.clamp(newValue)
        // Compared after clamping, so a write of 1000 to a count already at
        // the ceiling announces nothing. Otherwise holding a stepper at its
        // limit would re-trim the history and schedule a disk write per tick.
        guard clamped != self[keyPath: keyPath] else { return }
        self[keyPath: keyPath] = clamped
        defaults.set(clamped, forKey: key)
        onChange?()
    }

    private static func clamp(_ value: Int) -> Int {
        min(max(value, countRange.lowerBound), countRange.upperBound)
    }

    private enum Key {
        static let rememberCount = "rememberCount"
        static let displayCount = "displayCount"
        static let appliedDefaultLoginItem = "appliedDefaultLoginItem"
    }
}

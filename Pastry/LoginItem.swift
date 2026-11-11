import ServiceManagement

/// Whether Pastry starts when the user logs in.
///
/// Behind a protocol because the real implementation writes to the user's
/// actual login items and the change outlives the process — a test must never
/// reach it. The real one is constructed in `AppDelegate` only, which already
/// does nothing under a test run.
@MainActor
protocol LoginItem {
    var isEnabled: Bool { get }
    /// True when macOS has the registration but the user has not approved it
    /// yet, which it answers with instead of raising an error.
    var needsApproval: Bool { get }
    func setEnabled(_ enabled: Bool)
    func openSystemSettings()
}

/// The real one, over `SMAppService`.
@MainActor
struct SystemLoginItem: LoginItem {
    private var service: SMAppService { .mainApp }

    // Always asks the system, never remembers: the user can turn Pastry off
    // in System Settings, so only the system knows. Each call is a
    // synchronous round trip to smd of about a millisecond, which is why
    // Preferences keeps a mirror and refreshes it at the few moments the
    // answer can have changed, rather than calling this per redraw.
    var isEnabled: Bool { service.status == .enabled }
    var needsApproval: Bool { service.status == .requiresApproval }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            // Nothing can be done about it from here, and the toggle reads the
            // real status back afterwards, so a failure shows itself rather
            // than being asserted away.
            Log.clipboard.error(
                "could not change launch at login: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

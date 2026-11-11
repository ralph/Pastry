import AppKit

/// Reports the application the user is currently working in, so a captured
/// clip can say where it came from.
enum SystemFrontmostApp {
    @MainActor
    static func current() -> SourceApp? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return SourceApp(name: app.localizedName, bundleURL: app.bundleURL)
    }
}

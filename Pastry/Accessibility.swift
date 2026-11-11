import ApplicationServices

/// The Accessibility permission, which synthesising a keystroke requires.
enum Accessibility {
    /// The SDK exposes this as a mutable global, which Swift 6 refuses to read
    /// across isolation. The literal is the documented, stable key name.
    private static let promptOption = "AXTrustedCheckOptionPrompt"

    @MainActor
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system's "open System Settings" prompt. macOS shows it at most
    /// once per application per login session however often this is called.
    @MainActor
    static func requestTrust() {
        _ = AXIsProcessTrustedWithOptions([promptOption: true] as CFDictionary)
    }
}

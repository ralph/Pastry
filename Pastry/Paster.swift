import AppKit

enum PasteOutcome: Equatable {
    case pasted
    /// The clip is on the pasteboard, but Pastry may not synthesise keystrokes.
    case copiedWithoutPermission
}

/// Puts a clip where the user is typing.
///
/// Every system effect is injected, so the order of the steps and the
/// permission branch are testable without touching the real pasteboard,
/// focus or event stream.
@MainActor
final class Paster {
    private let write: (String) -> Void
    private let yieldFocus: () -> Void
    private let sendPaste: () -> Void
    private let isTrusted: () -> Bool
    private let requestTrust: () -> Void
    private let delay: Duration
    private var hasAskedForPermission = false

    init(
        write: @escaping (String) -> Void,
        yieldFocus: @escaping () -> Void = { NSApp.hide(nil) },
        sendPaste: @escaping () -> Void = { Keystroke.commandV() },
        isTrusted: @escaping () -> Bool = { Accessibility.isTrusted },
        requestTrust: @escaping () -> Void = { Accessibility.requestTrust() },
        delay: Duration = .milliseconds(200)
    ) {
        self.write = write
        self.yieldFocus = yieldFocus
        self.sendPaste = sendPaste
        self.isTrusted = isTrusted
        self.requestTrust = requestTrust
        self.delay = delay
    }

    @discardableResult
    func paste(_ text: String) async -> PasteOutcome {
        // The clip goes on the pasteboard either way: without permission the
        // user can still paste it by hand, which is far better than nothing.
        write(text)

        guard isTrusted() else {
            if !hasAskedForPermission {
                hasAskedForPermission = true
                requestTrust()
            }
            Log.clipboard.info("pasted nothing: Accessibility permission is not granted")
            return .copiedWithoutPermission
        }

        // Hiding returns the keyboard to the application the user came from.
        yieldFocus()
        // The window server moves focus asynchronously and reports no
        // completion, so the keystroke waits a moment. 0.2 s is Flycut's value.
        try? await Task.sleep(for: delay)
        sendPaste()
        return .pasted
    }
}

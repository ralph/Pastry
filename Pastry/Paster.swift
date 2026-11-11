import AppKit

enum PasteOutcome: String, Equatable {
    case pasted
    /// The clip is on the pasteboard, but Pastry may not synthesise keystrokes.
    case copiedWithoutPermission
    /// Permission was granted, but the event stream refused the keystroke.
    case keystrokeFailed
    /// Abandoned before the keystroke, so nothing was typed anywhere.
    case cancelled
    /// Another paste was still in flight; this one did nothing at all.
    case alreadyPasting
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
    private let sendPaste: () -> Bool
    private let isTrusted: () -> Bool
    private let requestTrust: () -> Void
    private let delay: Duration
    private var hasAskedForPermission = false
    private var isPasting = false

    init(
        write: @escaping (String) -> Void,
        yieldFocus: @escaping () -> Void = { NSApp.hide(nil) },
        sendPaste: @escaping () -> Bool = { Keystroke.commandV() },
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
        // Two pastes in flight would interleave across the wait: the first
        // would resume after the second had already replaced the pasteboard,
        // and post the second's clip. Reachable once a hotkey can start one.
        guard !isPasting else { return .alreadyPasting }

        // The clip goes on the pasteboard either way: without permission the
        // user can still paste it by hand, which is far better than nothing.
        write(text)

        guard isTrusted() else {
            if !hasAskedForPermission {
                hasAskedForPermission = true
                requestTrust()
            }
            return .copiedWithoutPermission
        }

        isPasting = true
        defer { isPasting = false }

        // Returns the keyboard to the application the user came from. On the
        // status-menu path there is usually nothing to give back — the menu
        // tracks without activating an LSUIElement app — but the bezel and
        // the About panel do take focus, and this is what hands it back.
        yieldFocus()

        do {
            // The window server moves focus asynchronously and reports no
            // completion, so the keystroke waits. 0.2 s is Flycut's value.
            try await Task.sleep(for: delay)
        } catch {
            // Cancelled. Falling through would fire the keystroke early, into
            // whatever happens to have focus now — the opposite of stopping.
            return .cancelled
        }

        return sendPaste() ? .pasted : .keystrokeFailed
    }
}

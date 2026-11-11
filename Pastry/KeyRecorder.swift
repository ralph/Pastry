import AppKit
import SwiftUI

/// The control that listens for a combination.
///
/// An `NSButton` subclass rather than a hand-drawn view: it brings the focus
/// ring, the pressed state, the contrast and transparency settings, and — the
/// part a custom view silently loses — a role and a title for VoiceOver.
///
/// What it does add is seeing keys before anything else interprets them.
/// `keyDown(with:)` is taken while recording, and so is
/// `performKeyEquivalent(with:)`: without the latter, recording ⌘Q would quit
/// Pastry and ⌘W would close the window instead of either being recorded.
final class KeyRecorderView: NSButton {
    var onOutcome: ((HotKeyRecordingOutcome) -> Void)?

    /// What to show when not recording.
    var combinationTitle = "" {
        didSet {
            guard combinationTitle != oldValue else { return }
            refreshTitle()
        }
    }

    private var isRecording = false {
        didSet {
            guard isRecording != oldValue else { return }
            state = isRecording ? .on : .off
            refreshTitle()
        }
    }

    // NSControl only takes first responder when full keyboard access is on,
    // and this control is useless if it cannot.
    override var acceptsFirstResponder: Bool { true }

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.pushOnPushOff)
        target = self
        action = #selector(startRecording)
        refreshTitle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    @objc private func startRecording() {
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        isRecording = true
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        let outcome = HotKeyRecording.outcome(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags
        )
        // Every outcome is conclusive: a modifier on its own arrives through
        // flagsChanged, which this never sees.
        window?.makeFirstResponder(nil)
        onOutcome?(outcome)
    }

    /// Keeps ⌘-anything from reaching the window's key equivalents, or
    /// NSApp's, while recording.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    private func refreshTitle() {
        title = isRecording ? "Press a combination…" : combinationTitle
    }
}

/// `KeyRecorderView` for SwiftUI.
struct KeyRecorder: NSViewRepresentable {
    let title: String
    let onOutcome: (HotKeyRecordingOutcome) -> Void

    func makeNSView(context: Context) -> KeyRecorderView {
        let view = KeyRecorderView()
        view.combinationTitle = title
        view.onOutcome = onOutcome
        return view
    }

    func updateNSView(_ view: KeyRecorderView, context: Context) {
        view.combinationTitle = title
        view.onOutcome = onOutcome
    }
}

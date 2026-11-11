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

    private var monitor: Any?

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
        // The button toggles its own state on every click. A second click
        // while already recording would turn it visually off while the
        // recorder went on listening, so the state is put back to whatever
        // is actually happening.
        state = isRecording ? .on : .off
    }

    override func becomeFirstResponder() -> Bool {
        isRecording = true
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    /// Watches keys for as long as the recorder has a window.
    ///
    /// A local monitor rather than `keyDown`, because by the time an event
    /// reaches a view AppKit has already acted on some of them: Tab moves
    /// focus, Space and Return work the button, and ⌘-anything is a key
    /// equivalent that the window or NSApp claims first. The monitor sees
    /// every one before any of that and can swallow it.
    ///
    /// Local, not global: this window belongs to the active application.
    /// Kept for the view's lifetime and gated on `isRecording`, rather than
    /// torn down from inside its own handler.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else {
            stopMonitoring()
            return
        }
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, isRecording else { return event }
            let outcome = HotKeyRecording.outcome(
                keyCode: event.keyCode,
                modifiers: event.modifierFlags
            )
            // Every outcome is conclusive: a modifier pressed on its own
            // arrives through flagsChanged, which this never matches.
            window?.makeFirstResponder(nil)
            onOutcome?(outcome)
            return nil
        }
    }

    private func stopMonitoring() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
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

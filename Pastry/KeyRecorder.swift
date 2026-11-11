import AppKit
import SwiftUI

/// The control that listens for a combination.
///
/// An `NSView` rather than anything SwiftUI offers, because it has to see key
/// events *before* they are interpreted. While it is recording it also takes
/// over `performKeyEquivalent(with:)`: without that, pressing ⌘Q to record it
/// would quit Pastry and ⌘W would close the window, instead of either being
/// recorded.
final class KeyRecorderView: NSView {
    var onOutcome: ((HotKeyRecordingOutcome) -> Void)?

    /// What to draw when not recording.
    var title = "" { didSet { needsDisplay = true } }

    private(set) var isRecording = false {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }

    override func becomeFirstResponder() -> Bool {
        isRecording = true
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
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
        // A modifier on its own is how every recording starts, so it leaves
        // the recorder listening. Everything else is conclusive.
        guard outcome != .ignored else { return }
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

    override func draw(_ dirtyRect: NSRect) {
        let rounded = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.15)
                     : NSColor.unemphasizedSelectedContentBackgroundColor).setFill()
        rounded.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        rounded.lineWidth = isRecording ? 2 : 1
        rounded.stroke()

        let text = isRecording ? "Press a combination…" : title
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: isRecording ? NSColor.secondaryLabelColor : NSColor.labelColor,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(
            at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2),
            withAttributes: attributes
        )
    }
}

/// `KeyRecorderView` for SwiftUI.
struct KeyRecorder: NSViewRepresentable {
    let title: String
    let onOutcome: (HotKeyRecordingOutcome) -> Void

    func makeNSView(context: Context) -> KeyRecorderView {
        let view = KeyRecorderView()
        view.title = title
        view.onOutcome = onOutcome
        return view
    }

    func updateNSView(_ view: KeyRecorderView, context: Context) {
        view.title = title
        view.onOutcome = onOutcome
    }
}

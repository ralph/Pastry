import AppKit

/// The parts of a pasteboard the monitor needs.
///
/// A protocol so the polling rules can be tested against a fake; the real
/// implementation is a thin wrapper over `NSPasteboard.general`. Type names are
/// plain strings to keep the protocol, and its fake, free of AppKit.
///
/// Writing is part of this protocol on purpose. Pastry must not re-record the
/// clip it just pasted, and the only way to suppress that without a race is for
/// the write itself to report the change count it produced — see
/// `ClipboardMonitor.write(_:)`.
@MainActor
protocol ClipboardSource {
    var changeCount: Int { get }
    func hasType(_ type: String) -> Bool

    /// Reads the pasteboard's plain text, off the main actor.
    ///
    /// The owning application supplies the data when it is asked for, and it
    /// may be slow to do so — a large copy from Remote Desktop, or a clip
    /// arriving from an iPhone over Universal Clipboard, can take seconds.
    /// Reading that on the main actor would freeze the menu bar for the
    /// duration, so the read happens elsewhere and only the result comes back.
    func string() async -> String?

    /// Replaces the pasteboard contents, returning the resulting change count.
    @discardableResult
    func write(_ text: String) -> Int
}

struct SystemClipboard: ClipboardSource {
    var changeCount: Int { NSPasteboard.general.changeCount }

    /// Asks the pasteboard directly rather than listing every type, which would
    /// allocate two throwaway arrays on each of the two polls per second.
    func hasType(_ type: String) -> Bool {
        NSPasteboard.general.availableType(from: [.init(type)]) != nil
    }

    func string() async -> String? {
        await Task.detached(priority: .userInitiated) {
            NSPasteboard.general.string(forType: .string)
        }.value
    }

    @discardableResult
    func write(_ text: String) -> Int {
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // clearContents() reports the count its own change produced; setString
        // does not bump it again, so this identifies the write exactly.
        return changeCount
    }
}

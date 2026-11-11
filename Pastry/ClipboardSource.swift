import AppKit

/// The parts of a pasteboard the monitor needs.
///
/// A protocol so the polling rules can be tested against a fake; the real
/// implementation is a thin wrapper over `NSPasteboard.general`. Types are
/// plain strings to keep the protocol, and its fake, free of AppKit.
@MainActor
protocol ClipboardSource {
    var changeCount: Int { get }
    var types: [String] { get }
    func string() -> String?
}

struct SystemClipboard: ClipboardSource {
    private var pasteboard: NSPasteboard { .general }

    var changeCount: Int { pasteboard.changeCount }

    var types: [String] { (pasteboard.types ?? []).map(\.rawValue) }

    func string() -> String? { pasteboard.string(forType: .string) }
}

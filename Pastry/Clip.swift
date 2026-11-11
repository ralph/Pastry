import Foundation

/// One entry in the clipboard history.
///
/// `appName` and `appBundleURL` describe where the text was copied from; both
/// are optional because the frontmost application cannot always be identified.
struct Clip: Equatable, Codable, Sendable {
    /// Characters shown per row in the status menu. The bezel shows the full text.
    static let displayLength = 40

    let text: String
    let appName: String?
    let appBundleURL: URL?
    let date: Date

    /// A single-line, length-capped rendering for menu rows.
    var displayText: String {
        let collapsed = text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard collapsed.count > Self.displayLength else { return collapsed }
        return String(collapsed.prefix(Self.displayLength - 1)) + "…"
    }
}

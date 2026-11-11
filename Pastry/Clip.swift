import Foundation

/// Where a clip was copied from.
struct SourceApp: Equatable, Sendable {
    let name: String?
    let bundleURL: URL?
}

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

    init(text: String, appName: String?, appBundleURL: URL?, date: Date) {
        self.text = text
        self.appName = appName
        self.appBundleURL = appBundleURL
        self.date = date
    }

    init(text: String, source: SourceApp?, date: Date) {
        self.init(
            text: text,
            appName: source?.name,
            appBundleURL: source?.bundleURL,
            date: date
        )
    }

    /// A single-line, length-capped rendering for menu rows.
    ///
    /// Stops reading as soon as it has one character more than it can show, so
    /// the cost is bounded by the display length rather than the clip size —
    /// this runs once per visible row every time the menu opens, and a clip can
    /// hold megabytes of pasted text.
    var displayText: String {
        var collapsed = ""
        collapsed.reserveCapacity(Self.displayLength + 1)
        var length = 0
        var pendingSpace = false

        for character in text {
            if character.isWhitespace {
                // Leading whitespace is dropped; a run between words becomes
                // one space, emitted only once a word follows it.
                pendingSpace = !collapsed.isEmpty
                continue
            }
            if pendingSpace {
                collapsed.append(" ")
                length += 1
                pendingSpace = false
            }
            collapsed.append(character)
            length += 1
            if length > Self.displayLength { break }
        }

        guard length > Self.displayLength else { return collapsed }
        return String(collapsed.prefix(Self.displayLength - 1)) + "…"
    }
}

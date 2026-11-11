import Foundation

/// The clipboard history, newest first.
///
/// Every rule about what the *list* contains lives here: duplicates move to the
/// top rather than piling up, clips with nothing to show are never stored, and
/// the list is capped. Nothing in here touches AppKit or the pasteboard, so it
/// is all directly testable.
@MainActor
final class ClipStore {
    private(set) var clips: [Clip] = []

    /// How many clips to keep. Lowering it discards the oldest immediately.
    ///
    /// Clamped at zero: a negative count would make `trim()` remove more clips
    /// than the list holds, which traps. Feature 8 binds this to a Preferences
    /// control, so the value stops being under this file's control.
    var rememberCount: Int {
        didSet {
            rememberCount = max(0, rememberCount)
            trim()
        }
    }

    init(rememberCount: Int = 40) {
        self.rememberCount = max(0, rememberCount)
    }

    var count: Int { clips.count }

    func clip(at index: Int) -> Clip? {
        clips.indices.contains(index) ? clips[index] : nil
    }

    /// Inserts at the top. Text already in the history moves up instead of
    /// being duplicated, carrying the newer app and timestamp with it.
    ///
    /// Clips whose display text is empty — blank or whitespace only — are
    /// rejected: they would occupy a history slot and draw an empty menu row.
    func add(_ clip: Clip) {
        guard !clip.displayText.isEmpty else { return }
        clips.removeAll { $0.text == clip.text }
        clips.insert(clip, at: 0)
        trim()
    }

    func remove(at index: Int) {
        guard clip(at: index) != nil else { return }
        clips.remove(at: index)
    }

    /// Moves an existing clip to the top, keeping its source app and date.
    ///
    /// Choosing a clip is not copying it afresh: the bezel shows when the text
    /// was first copied, so re-adding it through `add(_:)` — which stamps the
    /// current date — would be wrong.
    func moveToTop(at index: Int) {
        guard let clip = clip(at: index) else { return }
        clips.remove(at: index)
        clips.insert(clip, at: 0)
    }

    func clear() {
        clips.removeAll()
    }

    /// Joins every clip, oldest first, into one new clip at the top.
    ///
    /// Below two clips there is nothing to join, and merging anyway would
    /// replace the lone clip's source app and timestamp with Pastry's own —
    /// losing attribution the bezel displays, in exchange for nothing.
    func merge() {
        guard clips.count > 1 else { return }
        let merged = clips.reversed().map(\.text).joined(separator: "\n")
        add(Clip(text: merged, appName: "Pastry", appBundleURL: nil, date: Date()))
    }

    private func trim() {
        guard clips.count > rememberCount else { return }
        clips.removeLast(clips.count - rememberCount)
    }
}

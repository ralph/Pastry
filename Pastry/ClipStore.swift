import Foundation

/// The clipboard history, newest first.
///
/// Every rule about what the list contains lives here: duplicates move to the
/// top rather than piling up, empty text is never stored, and the list is
/// capped. Nothing in here touches AppKit or the pasteboard, so it is all
/// directly testable.
@MainActor
final class ClipStore {
    private(set) var clips: [Clip] = []

    /// How many clips to keep. Lowering it discards the oldest immediately.
    var rememberCount: Int {
        didSet { trim() }
    }

    init(rememberCount: Int = 40) {
        self.rememberCount = rememberCount
    }

    var count: Int { clips.count }

    func clip(at index: Int) -> Clip? {
        clips.indices.contains(index) ? clips[index] : nil
    }

    /// Inserts at the top. Text already in the history moves up instead of
    /// being duplicated, carrying the newer app and timestamp with it.
    func add(_ clip: Clip) {
        guard !clip.text.isEmpty else { return }
        clips.removeAll { $0.text == clip.text }
        clips.insert(clip, at: 0)
        trim()
    }

    func remove(at index: Int) {
        guard clips.indices.contains(index) else { return }
        clips.remove(at: index)
    }

    func clear() {
        clips.removeAll()
    }

    /// Joins every clip, oldest first, into one new clip at the top.
    func merge() {
        guard !clips.isEmpty else { return }
        let merged = clips.reversed().map(\.text).joined(separator: "\n")
        add(Clip(text: merged, appName: "Pastry", appBundleURL: nil, date: Date()))
    }

    private func trim() {
        guard clips.count > rememberCount else { return }
        clips.removeLast(clips.count - rememberCount)
    }
}

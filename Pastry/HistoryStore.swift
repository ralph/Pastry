import Foundation

/// Reads and writes the clipboard history.
///
/// `load()` never throws. Every way of failing — no file, unreadable file,
/// damaged contents — means the same thing to the app: start empty.
struct HistoryStore: Sendable {
    private let file: HistoryFile

    init(file: HistoryFile = DiskHistoryFile()) {
        self.file = file
    }

    func load() -> [Clip] {
        do {
            guard let data = try file.read() else { return [] }
            return try JSONDecoder().decode([Clip].self, from: data)
        } catch {
            // Deliberately not deleted. It is the user's clipboard history,
            // and leaving it is the only chance of recovering it by hand.
            Log.clipboard.error("could not read the history, starting empty: \(error)")
            return []
        }
    }

    /// Returns whether the history reached disk. A failed write must not be
    /// reported as done, or the change is lost with only a log line.
    @discardableResult
    func save(_ clips: [Clip]) -> Bool {
        do {
            try file.write(try JSONEncoder().encode(clips))
            return true
        } catch {
            Log.clipboard.error("could not write the history: \(error)")
            return false
        }
    }
}

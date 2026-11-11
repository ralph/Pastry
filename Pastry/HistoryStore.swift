import Foundation

/// Reads and writes the clipboard history.
///
/// `load()` never throws. Every way of failing — no file, unreadable file,
/// damaged contents — means the same thing to the app: start empty.
struct HistoryStore {
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

    func save(_ clips: [Clip]) {
        do {
            try file.write(try JSONEncoder().encode(clips))
        } catch {
            Log.clipboard.error("could not write the history: \(error)")
        }
    }
}

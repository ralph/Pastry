import Foundation

/// Where the history lives. A protocol so the store's rules can be tested
/// without touching disk.
protocol HistoryFile: Sendable {
    /// The stored bytes, or `nil` when there is no file yet — which is the
    /// ordinary first-launch case, not an error.
    func read() throws -> Data?
    func write(_ data: Data) throws
}

struct DiskHistoryFile: HistoryFile {
    /// Where the history lives in a real install.
    static let defaultURL: URL = {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return base.appending(path: "Pastry/history.json")
    }()

    let url: URL

    /// The location is injectable so the disk behaviour itself — creating the
    /// directory, writing atomically, the permissions — is testable against a
    /// temporary directory rather than the real install.
    init(url: URL = DiskHistoryFile.defaultURL) {
        self.url = url
    }

    func read() throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            return nil
        }
        return try Data(contentsOf: url)
    }

    func write(_ data: Data) throws {
        // The directory is owner-only, which is what actually protects the
        // history: an atomic write creates a temporary file with default
        // permissions and renames it into place, so the file itself is
        // briefly group- and world-readable on every single write.
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        // Atomic, so a crash mid-write cannot leave a half-written history.
        try data.write(to: url, options: [.atomic])

        // Belt and braces on top of the directory. Applied after the write,
        // because the atomic rename replaces the file and any permissions the
        // previous one carried. Deliberately not fatal: the data is on disk,
        // and reporting a failed write here would make the caller retry a
        // write that actually succeeded.
        do {
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path(percentEncoded: false)
            )
        } catch {
            Log.clipboard.error("history written but could not be restricted: \(error)")
        }
    }
}

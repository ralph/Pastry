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
    static let url: URL = {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return base.appending(path: "Pastry/history.json")
    }()

    func read() throws -> Data? {
        guard FileManager.default.fileExists(atPath: Self.url.path(percentEncoded: false)) else {
            return nil
        }
        return try Data(contentsOf: Self.url)
    }

    func write(_ data: Data) throws {
        try FileManager.default.createDirectory(
            at: Self.url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // Atomic, so a crash mid-write cannot leave a half-written history.
        try data.write(to: Self.url, options: [.atomic])
        // This file holds clipboard contents; keep it to the owner. Set after
        // the write because an atomic write replaces the file, and with it any
        // permissions set on the previous one.
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: Self.url.path(percentEncoded: false)
        )
    }
}

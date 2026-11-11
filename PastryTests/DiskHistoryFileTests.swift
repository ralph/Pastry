import Foundation
import Testing
@testable import Pastry

@Suite("DiskHistoryFile")
struct DiskHistoryFileTests {
    /// A unique temporary location, so these exercise the real file system
    /// without touching the install's own history.
    /// Returns the unique root and the file inside it. The root is returned
    /// rather than recovered by walking up a guessed number of path
    /// components — one component too far is the temporary directory itself.
    private func temporaryLocation() -> (root: URL, file: URL) {
        let root = URL.temporaryDirectory.appending(path: "PastryTests-\(UUID().uuidString)")
        return (root, root.appending(path: "Pastry/history.json"))
    }

    private func permissions(of url: URL) throws -> Int16 {
        let attributes = try FileManager.default.attributesOfItem(
            atPath: url.path(percentEncoded: false)
        )
        return try #require(attributes[.posixPermissions] as? NSNumber).int16Value
    }

    @Test("reports no data before anything is written")
    func readsNothingWhenAbsent() throws {
        let (root, url) = temporaryLocation()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(try DiskHistoryFile(url: url).read() == nil)
    }

    @Test("creates the directory it needs and round trips the bytes")
    func createsDirectoryAndRoundTrips() throws {
        let (root, url) = temporaryLocation()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = DiskHistoryFile(url: url)
        let payload = Data("history bytes".utf8)

        try file.write(payload)

        #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
        #expect(try file.read() == payload)
    }

    /// The file holds clipboard contents, so no other account may read it.
    @Test("writes the file readable only by its owner")
    func writesOwnerOnlyPermissions() throws {
        let (root, url) = temporaryLocation()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = DiskHistoryFile(url: url)

        try file.write(Data("secret".utf8))

        #expect(try permissions(of: url) == 0o600)
    }

    /// The directory is what actually protects the history: an atomic write
    /// creates a temporary file with default permissions and renames it into
    /// place, so the file itself is briefly readable by others on every write.
    @Test("puts the history in an owner-only directory")
    func directoryIsOwnerOnly() throws {
        let (root, url) = temporaryLocation()
        defer { try? FileManager.default.removeItem(at: root) }

        try DiskHistoryFile(url: url).write(Data("secret".utf8))

        #expect(try permissions(of: url.deletingLastPathComponent()) == 0o700)
    }

    /// An atomic write replaces the file, which would drop the permissions set
    /// on the previous one if they were not reapplied.
    @Test("keeps owner-only permissions when overwriting")
    func keepsPermissionsOnOverwrite() throws {
        let (root, url) = temporaryLocation()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = DiskHistoryFile(url: url)

        try file.write(Data("first".utf8))
        try file.write(Data("second".utf8))

        #expect(try permissions(of: url) == 0o600)
        #expect(try file.read() == Data("second".utf8))
    }

    @Test("the default location is inside Application Support")
    func defaultLocation() {
        let path = DiskHistoryFile.defaultURL.path(percentEncoded: false)
        #expect(path.hasSuffix("/Application Support/Pastry/history.json"))
    }
}

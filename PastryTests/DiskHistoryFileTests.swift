import Foundation
import Testing
@testable import Pastry

@Suite("DiskHistoryFile")
struct DiskHistoryFileTests {
    /// A unique temporary location, so these exercise the real file system
    /// without touching the install's own history.
    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "PastryTests-\(UUID().uuidString)")
            .appending(path: "Pastry/history.json")
    }

    private func cleanUp(_ url: URL) {
        try? FileManager.default.removeItem(
            at: url.deletingLastPathComponent().deletingLastPathComponent()
        )
    }

    @Test("reports no data before anything is written")
    func readsNothingWhenAbsent() throws {
        let url = temporaryURL()
        defer { cleanUp(url) }
        #expect(try DiskHistoryFile(url: url).read() == nil)
    }

    @Test("creates the directory it needs and round trips the bytes")
    func createsDirectoryAndRoundTrips() throws {
        let url = temporaryURL()
        defer { cleanUp(url) }
        let file = DiskHistoryFile(url: url)
        let payload = Data("history bytes".utf8)

        try file.write(payload)

        #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
        #expect(try file.read() == payload)
    }

    /// The file holds clipboard contents, so no other account may read it.
    @Test("writes the file readable only by its owner")
    func writesOwnerOnlyPermissions() throws {
        let url = temporaryURL()
        defer { cleanUp(url) }
        let file = DiskHistoryFile(url: url)

        try file.write(Data("secret".utf8))

        let attributes = try FileManager.default.attributesOfItem(
            atPath: url.path(percentEncoded: false)
        )
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(permissions.int16Value == 0o600)
    }

    /// An atomic write replaces the file, which would drop the permissions set
    /// on the previous one if they were not reapplied.
    @Test("keeps owner-only permissions when overwriting")
    func keepsPermissionsOnOverwrite() throws {
        let url = temporaryURL()
        defer { cleanUp(url) }
        let file = DiskHistoryFile(url: url)

        try file.write(Data("first".utf8))
        try file.write(Data("second".utf8))

        let attributes = try FileManager.default.attributesOfItem(
            atPath: url.path(percentEncoded: false)
        )
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(permissions.int16Value == 0o600)
        #expect(try file.read() == Data("second".utf8))
    }

    @Test("the default location is inside Application Support")
    func defaultLocation() {
        let path = DiskHistoryFile.defaultURL.path(percentEncoded: false)
        #expect(path.hasSuffix("/Application Support/Pastry/history.json"))
    }
}

import Foundation
import Testing
@testable import Pastry

/// A history file held in memory, so the rules are tested without disk.
private final class FakeHistoryFile: HistoryFile, @unchecked Sendable {
    var data: Data?
    var readError: Error?
    var writeError: Error?
    private(set) var writeCount = 0

    func read() throws -> Data? {
        if let readError { throw readError }
        return data
    }

    func write(_ data: Data) throws {
        writeCount += 1
        if let writeError { throw writeError }
        self.data = data
    }
}

private struct Boom: Error {}

@Suite("HistoryStore")
struct HistoryStoreTests {
    @Test("round trips clips through the file")
    func roundTrip() {
        let file = FakeHistoryFile()
        let clips = [
            Clip.fixture("newest", app: "Safari", at: 200),
            Clip.fixture("oldest", app: "Terminal", at: 100),
        ]

        HistoryStore(file: file).save(clips)

        #expect(HistoryStore(file: file).load() == clips)
    }

    @Test("an absent file means an empty history")
    func absentFile() {
        #expect(HistoryStore(file: FakeHistoryFile()).load().isEmpty)
    }

    @Test("a file that cannot be read means an empty history")
    func unreadableFile() {
        let file = FakeHistoryFile()
        file.readError = Boom()
        #expect(HistoryStore(file: file).load().isEmpty)
    }

    @Test("a damaged file means an empty history")
    func malformedFile() {
        let file = FakeHistoryFile()
        file.data = Data("this is not JSON".utf8)
        #expect(HistoryStore(file: file).load().isEmpty)
    }

    /// It is the user's clipboard history. Starting empty is recoverable;
    /// deleting the file is not.
    @Test("leaves a damaged file on disk")
    func doesNotDeleteDamagedFile() {
        let file = FakeHistoryFile()
        let damaged = Data("this is not JSON".utf8)
        file.data = damaged

        _ = HistoryStore(file: file).load()

        #expect(file.data == damaged)
        #expect(file.writeCount == 0)
    }

    @Test("a failing write is survivable")
    func writeFailureDoesNotCrash() {
        let file = FakeHistoryFile()
        file.writeError = Boom()
        HistoryStore(file: file).save([Clip.fixture("a")])
        #expect(file.writeCount == 1)
    }

    @Test("saving an empty history writes an empty list, not nothing")
    func savingEmpty() {
        let file = FakeHistoryFile()
        let store = HistoryStore(file: file)
        store.save([Clip.fixture("a")])
        store.save([])
        #expect(store.load().isEmpty)
        #expect(file.data != nil)
    }
}

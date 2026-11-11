import Foundation
import Testing
@testable import Pastry

@Suite("ClipStore")
@MainActor
struct ClipStoreTests {
    private func clip(_ text: String, app: String? = "Safari", at seconds: TimeInterval = 0) -> Clip {
        Clip(text: text, appName: app, appBundleURL: nil, date: Date(timeIntervalSince1970: seconds))
    }

    @Test("starts empty")
    func startsEmpty() {
        #expect(ClipStore().count == 0)
    }

    @Test("inserts new clips at the front")
    func newestFirst() {
        let store = ClipStore()
        store.add(clip("first"))
        store.add(clip("second"))
        #expect(store.clips.map(\.text) == ["second", "first"])
    }

    @Test("moves a duplicate to the front instead of adding a second copy")
    func duplicateMovesToFront() {
        let store = ClipStore()
        store.add(clip("a"))
        store.add(clip("b"))
        store.add(clip("a"))
        #expect(store.clips.map(\.text) == ["a", "b"])
        #expect(store.count == 2)
    }

    @Test("a duplicate carries the newer app and date")
    func duplicateTakesNewerMetadata() {
        let store = ClipStore()
        store.add(clip("a", app: "Safari", at: 100))
        store.add(clip("a", app: "Terminal", at: 200))
        #expect(store.clips.first?.appName == "Terminal")
        #expect(store.clips.first?.date == Date(timeIntervalSince1970: 200))
    }

    @Test("never stores empty text")
    func ignoresEmptyText() {
        let store = ClipStore()
        store.add(clip(""))
        #expect(store.count == 0)
    }

    @Test("drops the oldest clip once full")
    func capsAtRememberCount() {
        let store = ClipStore(rememberCount: 3)
        for text in ["1", "2", "3", "4"] { store.add(clip(text)) }
        #expect(store.clips.map(\.text) == ["4", "3", "2"])
    }

    @Test("trims immediately when the remember count is lowered")
    func loweringRememberCountTrims() {
        let store = ClipStore(rememberCount: 5)
        for text in ["1", "2", "3", "4", "5"] { store.add(clip(text)) }
        store.rememberCount = 2
        #expect(store.clips.map(\.text) == ["5", "4"])
    }

    @Test("reads a clip by index and returns nil out of range")
    func clipAtIndex() {
        let store = ClipStore()
        store.add(clip("only"))
        #expect(store.clip(at: 0)?.text == "only")
        #expect(store.clip(at: 1) == nil)
        #expect(store.clip(at: -1) == nil)
    }

    @Test("removes a clip by index and ignores an out-of-range index")
    func removeAtIndex() {
        let store = ClipStore()
        store.add(clip("old"))
        store.add(clip("new"))
        store.remove(at: 0)
        #expect(store.clips.map(\.text) == ["old"])
        store.remove(at: 9)
        #expect(store.count == 1)
    }

    @Test("clear empties the history")
    func clearEmpties() {
        let store = ClipStore()
        store.add(clip("a"))
        store.clear()
        #expect(store.count == 0)
    }

    @Test("merge joins every clip oldest first and puts the result on top")
    func mergeJoinsOldestFirst() {
        let store = ClipStore()
        store.add(clip("first"))
        store.add(clip("second"))
        store.merge()
        #expect(store.clips.first?.text == "first\nsecond")
        #expect(store.count == 3)
    }

    @Test("merge does nothing to an empty history")
    func mergeOnEmptyStore() {
        let store = ClipStore()
        store.merge()
        #expect(store.count == 0)
    }

    /// Merging one clip produces text identical to that clip, so deduplication
    /// folds it back into the original rather than adding a copy.
    @Test("merging a single clip leaves the history unchanged")
    func mergeOfSingleClipIsANoOp() {
        let store = ClipStore()
        store.add(clip("alone"))
        store.merge()
        #expect(store.clips.map(\.text) == ["alone"])
    }
}

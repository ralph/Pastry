import Foundation
import Testing
@testable import Pastry

@Suite("ClipStore")
@MainActor
struct ClipStoreTests {
    @Test("starts empty")
    func startsEmpty() {
        #expect(ClipStore().count == 0)
    }

    @Test("inserts new clips at the front")
    func newestFirst() {
        let store = ClipStore()
        store.add(Clip.fixture("first"))
        store.add(Clip.fixture("second"))
        #expect(store.clips.map(\.text) == ["second", "first"])
    }

    @Test("moves a duplicate to the front instead of adding a second copy")
    func duplicateMovesToFront() {
        let store = ClipStore()
        store.add(Clip.fixture("a"))
        store.add(Clip.fixture("b"))
        store.add(Clip.fixture("a"))
        #expect(store.clips.map(\.text) == ["a", "b"])
        #expect(store.count == 2)
    }

    @Test("a duplicate carries the newer app and date")
    func duplicateTakesNewerMetadata() {
        let store = ClipStore()
        store.add(Clip.fixture("a", app: "Safari", at: 100))
        store.add(Clip.fixture("a", app: "Terminal", at: 200))
        #expect(store.clips.first?.appName == "Terminal")
        #expect(store.clips.first?.date == Date(timeIntervalSince1970: 200))
    }

    @Test("never stores empty text")
    func ignoresEmptyText() {
        let store = ClipStore()
        store.add(Clip.fixture(""))
        #expect(store.count == 0)
    }

    /// A whitespace-only clip has an empty display text, so it would take a
    /// history slot and draw a blank menu row.
    @Test("never stores whitespace-only text")
    func ignoresWhitespaceOnlyText() {
        let store = ClipStore()
        store.add(Clip.fixture("   \n\t  "))
        #expect(store.count == 0)
    }

    @Test("drops the oldest clip once full")
    func capsAtRememberCount() {
        let store = ClipStore(rememberCount: 3)
        for text in ["1", "2", "3", "4"] { store.add(Clip.fixture(text)) }
        #expect(store.clips.map(\.text) == ["4", "3", "2"])
    }

    @Test("trims immediately when the remember count is lowered")
    func loweringRememberCountTrims() {
        let store = ClipStore(rememberCount: 5)
        for text in ["1", "2", "3", "4", "5"] { store.add(Clip.fixture(text)) }
        store.rememberCount = 2
        #expect(store.clips.map(\.text) == ["5", "4"])
    }

    /// A negative count made trim() remove more clips than the list held,
    /// which traps. Feature 8 binds this to a Preferences control.
    @Test("survives a negative remember count instead of trapping")
    func negativeRememberCountIsClamped() {
        let store = ClipStore()
        for text in ["1", "2", "3"] { store.add(Clip.fixture(text)) }
        store.rememberCount = -1
        #expect(store.rememberCount == 0)
        #expect(store.count == 0)
    }

    @Test("clamps a negative remember count passed to the initialiser")
    func negativeRememberCountInInitIsClamped() {
        #expect(ClipStore(rememberCount: -5).rememberCount == 0)
    }

    @Test("a remember count of zero keeps nothing")
    func zeroRememberCountKeepsNothing() {
        let store = ClipStore(rememberCount: 0)
        store.add(Clip.fixture("vanishes"))
        #expect(store.count == 0)
    }

    @Test("reads a clip by index and returns nil out of range")
    func clipAtIndex() {
        let store = ClipStore()
        store.add(Clip.fixture("only"))
        #expect(store.clip(at: 0)?.text == "only")
        #expect(store.clip(at: 1) == nil)
        #expect(store.clip(at: -1) == nil)
    }

    @Test("removes a clip by index and ignores an out-of-range index")
    func removeAtIndex() {
        let store = ClipStore()
        store.add(Clip.fixture("old"))
        store.add(Clip.fixture("new"))
        store.remove(at: 0)
        #expect(store.clips.map(\.text) == ["old"])
        store.remove(at: 9)
        #expect(store.count == 1)
    }

    @Test("moves a clip to the top keeping its app and date")
    func moveToTopPreservesMetadata() {
        let store = ClipStore()
        let older = Clip.fixture("older", app: "Safari", at: 100)
        store.add(older)
        store.add(Clip.fixture("newer", app: "Terminal", at: 200))
        store.moveToTop(older)
        #expect(store.clips.map(\.text) == ["older", "newer"])
        #expect(store.clips.first?.appName == "Safari")
        #expect(store.clips.first?.date == Date(timeIntervalSince1970: 100))
    }

    /// The caller may be holding a copy read before the list shifted, so the
    /// stored clip's own metadata wins over the one passed in.
    @Test("keeps the stored clip's metadata, not the caller's copy")
    func moveToTopPrefersTheStoredClip() {
        let store = ClipStore()
        store.add(Clip.fixture("shared", app: "Safari", at: 100))
        store.add(Clip.fixture("other"))
        store.moveToTop(Clip.fixture("shared", app: "Stale", at: 999))
        #expect(store.clips.first?.appName == "Safari")
        #expect(store.clips.first?.date == Date(timeIntervalSince1970: 100))
    }

    @Test("ignores a clip that is not in the history")
    func moveToTopOfAnAbsentClip() {
        let store = ClipStore()
        store.add(Clip.fixture("only"))
        store.moveToTop(Clip.fixture("never added"))
        #expect(store.clips.map(\.text) == ["only"])
    }

    @Test("an empty query returns the newest clips up to the limit")
    func searchWithEmptyQuery() {
        let store = ClipStore()
        for text in ["one", "two", "three"] { store.add(Clip.fixture(text)) }
        #expect(store.search("", limit: 2).map(\.text) == ["three", "two"])
    }

    @Test("matches anywhere in the text, ignoring case")
    func searchMatchesSubstringIgnoringCase() {
        let store = ClipStore()
        store.add(Clip.fixture("Hello World"))
        store.add(Clip.fixture("goodbye"))
        #expect(store.search("LO WO", limit: 10).map(\.text) == ["Hello World"])
    }

    @Test("keeps newest-first order among matches")
    func searchKeepsOrder() {
        let store = ClipStore()
        store.add(Clip.fixture("alpha one"))
        store.add(Clip.fixture("beta"))
        store.add(Clip.fixture("alpha two"))
        #expect(store.search("alpha", limit: 10).map(\.text) == ["alpha two", "alpha one"])
    }

    @Test("caps matches at the limit")
    func searchCapsAtLimit() {
        let store = ClipStore()
        for text in ["match 1", "match 2", "match 3"] { store.add(Clip.fixture(text)) }
        #expect(store.search("match", limit: 2).count == 2)
    }

    @Test("returns nothing when nothing matches")
    func searchWithNoMatches() {
        let store = ClipStore()
        store.add(Clip.fixture("hello"))
        #expect(store.search("nothing like it", limit: 10).isEmpty)
    }

    /// The rows show collapsed whitespace, but the search runs over the real
    /// text, so a phrase broken across a newline still matches.
    @Test("matches across the original line breaks")
    func searchMatchesAcrossNewlines() {
        let store = ClipStore()
        store.add(Clip.fixture("first line\nsecond line"))
        #expect(store.search("second", limit: 10).count == 1)
    }

    @Test("clear empties the history")
    func clearEmpties() {
        let store = ClipStore()
        store.add(Clip.fixture("a"))
        store.clear()
        #expect(store.count == 0)
    }

    @Test("merge joins every clip oldest first and puts the result on top")
    func mergeJoinsOldestFirst() {
        let store = ClipStore()
        store.add(Clip.fixture("first"))
        store.add(Clip.fixture("second"))
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

    /// Guarded explicitly: without it, dedup would replace the lone clip with
    /// one attributed to Pastry and stamped now, losing the source app and
    /// timestamp the bezel shows.
    @Test("merging a single clip changes nothing, including its attribution")
    func mergeOfSingleClipIsANoOp() {
        let store = ClipStore()
        store.add(Clip.fixture("alone", app: "Safari", at: 100))
        store.merge()
        #expect(store.clips.map(\.text) == ["alone"])
        #expect(store.clips.first?.appName == "Safari")
        #expect(store.clips.first?.date == Date(timeIntervalSince1970: 100))
    }

    @Test("the merged clip is attributed to Pastry")
    func mergedClipAttribution() {
        let store = ClipStore()
        store.add(Clip.fixture("first"))
        store.add(Clip.fixture("second"))
        store.merge()
        #expect(store.clips.first?.appName == "Pastry")
    }
}

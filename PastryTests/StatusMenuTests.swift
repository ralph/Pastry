import AppKit
import Testing
@testable import Pastry

@Suite("StatusMenu")
@MainActor
struct StatusMenuTests {
    private func makeMenu(
        clips: [String] = [],
        displayCount: Int = 30,
        onSelect: @escaping (Clip) -> Void = { _ in }
    ) -> (ClipStore, StatusMenu) {
        let store = ClipStore()
        for text in clips { store.add(Clip.fixture(text)) }
        let menu = StatusMenu(store: store, displayCount: displayCount, onSelect: onSelect)
        menu.rebuild()
        return (store, menu)
    }

    private func titles(_ menu: StatusMenu) -> [String] {
        menu.menu.items.map(\.title)
    }

    @Test("lists the clips newest first")
    func listsClipsNewestFirst() {
        let (_, menu) = makeMenu(clips: ["oldest", "newest"])
        #expect(Array(titles(menu).prefix(2)) == ["newest", "oldest"])
    }

    @Test("shows each clip's display text, not its raw text")
    func usesDisplayText() {
        let (_, menu) = makeMenu(clips: ["two\nlines"])
        #expect(titles(menu).first == "two lines")
    }

    @Test("lists at most the display count")
    func capsRowsAtDisplayCount() {
        let (_, menu) = makeMenu(clips: ["1", "2", "3", "4", "5"], displayCount: 2)
        #expect(Array(titles(menu).prefix(2)) == ["5", "4"])
        #expect(!titles(menu).contains("3"))
    }

    @Test("shows a disabled placeholder when the history is empty")
    func emptyStatePlaceholder() {
        let (_, menu) = makeMenu()
        let first = menu.menu.items.first
        #expect(first?.title == "No clippings")
        #expect(first?.isEnabled == false)
    }

    @Test("offers Clear All, Merge All, About and Quit")
    func fixedItemsPresent() {
        let (_, menu) = makeMenu(clips: ["a"])
        let rows = titles(menu)
        #expect(rows.contains("Clear All"))
        #expect(rows.contains("Merge All"))
        #expect(rows.contains("About Pastry"))
        #expect(rows.contains("Quit Pastry"))
    }

    @Test("Quit is wired to terminate on Command-Q")
    func quitWiring() {
        let (_, menu) = makeMenu()
        let quit = menu.menu.items.first { $0.title == "Quit Pastry" }
        #expect(quit?.action == #selector(NSApplication.terminate(_:)))
        #expect(quit?.keyEquivalent == "q")
    }

    @Test("choosing a row reports that clip")
    func choosingARowReportsTheClip() {
        var chosen: [String] = []
        let (_, menu) = makeMenu(clips: ["older", "newer"]) { chosen.append($0.text) }
        let row = menu.menu.items[1]
        _ = row.target?.perform(row.action, with: row)
        #expect(chosen == ["older"])
    }

    @Test("choosing a row moves it to the top of the history")
    func choosingARowMovesItToTheTop() {
        let (store, menu) = makeMenu(clips: ["older", "newer"])
        let row = menu.menu.items[1]
        _ = row.target?.perform(row.action, with: row)
        #expect(store.clips.map(\.text) == ["older", "newer"])
    }

    @Test("Clear All empties the history and the rows")
    func clearAllEmptiesTheStore() {
        let (store, menu) = makeMenu(clips: ["a", "b"])
        let clear = menu.menu.items.first { $0.title == "Clear All" }!
        _ = clear.target?.perform(clear.action, with: clear)
        #expect(store.count == 0)
        menu.rebuild()
        #expect(titles(menu).first == "No clippings")
    }

    @Test("Merge All joins the history into one clip on top")
    func mergeAllJoins() {
        let (store, menu) = makeMenu(clips: ["first", "second"])
        let merge = menu.menu.items.first { $0.title == "Merge All" }!
        _ = merge.target?.perform(merge.action, with: merge)
        #expect(store.clips.first?.text == "first\nsecond")
    }

    /// Rows are refreshed from the delegate callback AppKit makes just before
    /// the menu opens. If that stopped happening the menu would show whatever
    /// existed at launch, so assert the callback itself does the work.
    @Test("the menu delegate callback refreshes the rows")
    func delegateCallbackRebuilds() {
        let (store, menu) = makeMenu()
        #expect(titles(menu).first == "No clippings")

        store.add(Clip.fixture("arrived while closed"))
        menu.menuNeedsUpdate(menu.menu)
        #expect(titles(menu).first == "arrived while closed")
    }

    @Test("rebuilding does not accumulate rows")
    func rebuildIsIdempotent() {
        let (_, menu) = makeMenu(clips: ["a"])
        let before = menu.menu.items.count
        menu.rebuild()
        menu.rebuild()
        #expect(menu.menu.items.count == before)
    }
}

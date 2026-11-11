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
        refresh(menu)
        return (store, menu)
    }

    /// Drives the same delegate callback AppKit makes before the menu opens,
    /// so every test exercises the real path.
    private func refresh(_ menu: StatusMenu) {
        menu.menuNeedsUpdate(menu.menu)
    }

    /// The clip rows, found by their action rather than by position — feature 5
    /// adds a search field above them.
    private func clipRows(_ menu: StatusMenu) -> [NSMenuItem] {
        menu.menu.items.filter { $0.representedObject is Clip }
    }

    private func clipTitles(_ menu: StatusMenu) -> [String] {
        clipRows(menu).map(\.title)
    }

    /// Types into the search field through the same delegate callback AppKit
    /// invokes, rather than a seam that merely imitates it.
    private func type(_ text: String, into menu: StatusMenu) {
        menu.searchField.stringValue = text
        menu.controlTextDidChange(
            Notification(name: NSControl.textDidChangeNotification, object: menu.searchField)
        )
    }

    private func choose(_ item: NSMenuItem) {
        _ = item.target?.perform(item.action, with: item)
    }

    @Test("lists the clips newest first")
    func listsClipsNewestFirst() {
        let (_, menu) = makeMenu(clips: ["oldest", "newest"])
        #expect(clipTitles(menu) == ["newest", "oldest"])
    }

    @Test("shows each clip's display text, not its raw text")
    func usesDisplayText() {
        let (_, menu) = makeMenu(clips: ["two\nlines"])
        #expect(clipTitles(menu) == ["two lines"])
    }

    @Test("lists at most the display count")
    func capsRowsAtDisplayCount() {
        let (_, menu) = makeMenu(clips: ["1", "2", "3", "4", "5"], displayCount: 2)
        #expect(clipTitles(menu) == ["5", "4"])
    }

    @Test("shows an unclickable placeholder when the history is empty")
    func emptyStatePlaceholder() {
        let (_, menu) = makeMenu()
        let first = menu.menu.items.first
        #expect(first?.title == "No clippings")
        // A nil action is what makes it unclickable. isEnabled would be
        // recomputed by AppKit at display time, so asserting it proves nothing.
        #expect(first?.action == nil)
    }

    @Test("offers Clear All, Merge All, Settings, About and Quit")
    func fixedItemsPresent() {
        let (_, menu) = makeMenu(clips: ["a"])
        #expect(menu.menu.item(withTitle: "Clear All") != nil)
        #expect(menu.menu.item(withTitle: "Merge All") != nil)
        #expect(menu.menu.item(withTitle: "Settings…") != nil)
        #expect(menu.menu.item(withTitle: "About Pastry") != nil)
        #expect(menu.menu.item(withTitle: "Quit Pastry") != nil)
    }

    /// It used to be a fixed 240-wide island with the rows above it running
    /// past both edges. AppKit does not stretch a custom menu-item view, so
    /// the width is set by hand whenever the rows are rebuilt.
    @Test("the search field row spans the menu")
    func searchFieldSpansTheMenu() throws {
        let long = "a clipping long enough to make the menu a good deal wider than the default"
        let (_, menu) = makeMenu(clips: [long])
        let container = try #require(menu.searchFieldItem.view)

        #expect(container.frame.width >= menu.menu.size.width - 0.5)
        #expect(container.frame.width > 240)
    }

    /// The field is inset inside its row rather than filling it edge to edge,
    /// so it lines up with the row text and has air above and below.
    @Test("the search field is inset within its row")
    func searchFieldIsInset() throws {
        let (_, menu) = makeMenu(clips: ["a"])
        let container = try #require(menu.searchFieldItem.view)

        #expect(menu.searchField.frame.width < container.frame.width)
        #expect(menu.searchField.frame.height < container.frame.height)
        #expect(menu.searchField.frame.minX > 0)
        #expect(menu.searchField.frame.minY > 0)
    }

    @Test("Settings uses the standard shortcut and calls back")
    func settingsWiring() {
        let (_, menu) = makeMenu()
        let item = menu.menu.item(withTitle: "Settings…")
        #expect(item?.keyEquivalent == ",")
        #expect(item?.keyEquivalentModifierMask == .command)

        var opened = 0
        menu.onOpenPreferences = { opened += 1 }
        choose(item!)
        #expect(opened == 1)
    }

    /// Lowering it in Preferences has to shorten the menu now, not at the
    /// next launch.
    @Test("shows fewer rows when the display count is lowered")
    func honoursALoweredDisplayCount() {
        let (_, menu) = makeMenu(clips: (0..<10).map { "clip \($0)" }, displayCount: 10)
        #expect(clipRows(menu).count == 10)

        menu.displayCount = 3
        refresh(menu)
        #expect(clipRows(menu).count == 3)
    }

    @Test("Quit terminates through the responder chain on Command-Q")
    func quitWiring() {
        let (_, menu) = makeMenu()
        let quit = menu.menu.item(withTitle: "Quit Pastry")
        #expect(quit?.action == #selector(NSApplication.terminate(_:)))
        #expect(quit?.keyEquivalent == "q")
        // No target, so the action travels the responder chain to NSApp.
        #expect(quit?.target == nil)
    }

    @Test("choosing a row reports that clip")
    func choosingARowReportsTheClip() {
        var chosen: [String] = []
        let (_, menu) = makeMenu(clips: ["older", "newer"]) { chosen.append($0.text) }
        choose(clipRows(menu)[1])
        #expect(chosen == ["older"])
    }

    /// The monitor keeps polling while the menu is open, so a clip can arrive
    /// and shift every row's position. A row that carried its index would then
    /// act on a different clip than the one whose title the user read.
    @Test("a row still reports its own clip after a capture shifts the history")
    func rowSurvivesHistoryShiftWhileOpen() {
        var chosen: [String] = []
        let (store, menu) = makeMenu(clips: ["older", "newer"]) { chosen.append($0.text) }
        let row = clipRows(menu)[1]

        store.add(Clip.fixture("arrived while the menu was open"))
        choose(row)

        #expect(chosen == ["older"])
    }

    @Test("Clear All empties the history and the rows")
    func clearAllEmptiesTheStore() {
        let (store, menu) = makeMenu(clips: ["a", "b"])
        choose(menu.menu.item(withTitle: "Clear All")!)
        #expect(store.count == 0)
        refresh(menu)
        #expect(menu.menu.items.first?.title == "No clippings")
    }

    @Test("Merge All joins the history into one clip on top")
    func mergeAllJoins() {
        let (store, menu) = makeMenu(clips: ["first", "second"])
        choose(menu.menu.item(withTitle: "Merge All")!)
        #expect(store.clips.first?.text == "first\nsecond")
    }

    @Test("the delegate callback picks up a clip captured while the menu was closed")
    func refreshPicksUpNewClips() {
        let (store, menu) = makeMenu()
        #expect(menu.menu.items.first?.title == "No clippings")

        store.add(Clip.fixture("arrived while closed"))
        refresh(menu)

        #expect(clipTitles(menu) == ["arrived while closed"])
    }

    @Test("shows a search field below the clip rows")
    func hasASearchField() throws {
        let (_, menu) = makeMenu(clips: ["a"])
        let fieldRow = try #require(menu.menu.items.firstIndex(of: menu.searchFieldItem))
        let lastClipRow = try #require(menu.menu.items.lastIndex { $0.representedObject is Clip })
        #expect(fieldRow > lastClipRow)
    }

    @Test("narrows the rows to clips containing the query")
    func filtersRows() {
        let (_, menu) = makeMenu(clips: ["alpha", "beta", "alpha two"])
        type("alpha", into: menu)
        #expect(clipTitles(menu) == ["alpha two", "alpha"])
    }

    @Test("shows a no-match row when the query matches nothing")
    func noMatchRow() {
        let (_, menu) = makeMenu(clips: ["alpha"])
        type("zzz", into: menu)
        #expect(clipRows(menu).isEmpty)
        #expect(menu.menu.items.first?.title == "No matches")
        #expect(menu.menu.items.first?.action == nil)
    }

    /// A filter that outlived the menu would silently hide clips the next time
    /// it opened, with nothing on screen explaining why.
    @Test("forgets the query when the menu closes")
    func queryResetsOnClose() {
        let (_, menu) = makeMenu(clips: ["alpha", "beta"])
        type("alpha", into: menu)
        #expect(clipTitles(menu) == ["alpha"])

        menu.menuDidClose(menu.menu)

        #expect(menu.query.isEmpty)
        #expect(menu.searchField.stringValue.isEmpty)
        #expect(clipTitles(menu) == ["beta", "alpha"])
    }

    @Test("keeps the empty-history wording when there is nothing at all")
    func emptyHistoryWordingWins() {
        let (_, menu) = makeMenu()
        type("anything", into: menu)
        #expect(menu.menu.items.first?.title == "No clippings")
    }

    /// controlTextDidChange is shared across every control the object is a
    /// delegate for, so it must ignore notifications from anything else.
    @Test("ignores a text change from another control")
    func ignoresOtherControls() {
        let (_, menu) = makeMenu(clips: ["alpha", "beta"])
        let other = NSSearchField()
        other.stringValue = "alpha"
        menu.controlTextDidChange(
            Notification(name: NSControl.textDidChangeNotification, object: other)
        )
        #expect(menu.query.isEmpty)
        #expect(clipTitles(menu) == ["beta", "alpha"])
    }

    /// The field's editor swallows arrow keys, so without this a user who
    /// typed to narrow the list could not reach the row without the mouse.
    @Test("hands arrow keys back to the menu rows", arguments: [
        #selector(NSResponder.moveDown(_:)),
        #selector(NSResponder.moveUp(_:)),
    ])
    func arrowKeysLeaveTheSearchField(selector: Selector) {
        let (_, menu) = makeMenu(clips: ["alpha"])
        let handled = menu.control(
            menu.searchField,
            textView: NSTextView(),
            doCommandBy: selector
        )
        #expect(handled)
    }

    @Test("leaves other editing commands to the field")
    func otherCommandsStayInTheField() {
        let (_, menu) = makeMenu(clips: ["alpha"])
        let handled = menu.control(
            menu.searchField,
            textView: NSTextView(),
            doCommandBy: #selector(NSResponder.deleteBackward(_:))
        )
        #expect(!handled)
    }

    @Test("refreshing does not accumulate rows")
    func refreshIsIdempotent() {
        let (_, menu) = makeMenu(clips: ["a"])
        let before = menu.menu.items.count
        refresh(menu)
        refresh(menu)
        #expect(menu.menu.items.count == before)
    }
}

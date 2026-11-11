# Pastry Feature 5: Search field in the menu — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Type in the status menu to narrow the clip rows to those containing what you typed.

**Architecture:** `ClipStore` gains a pure `search`. `StatusMenu` holds the current query, puts an `NSSearchField` in a custom-view menu item, and rebuilds the rows through `search`. The hard part is focus, and it is entirely in `AppDelegate`: a status menu opens without activating an `LSUIElement` app, so the field can never become first responder on its own.

**Tech Stack:** Swift 6, AppKit, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-11-pastry-swift-rewrite-design.md`

## The focus problem, and why the solution looks strange

Clicking a status item tracks its menu in a nested run loop **without activating
the application**. Nothing in that menu can become first responder, so an
`NSSearchField` there receives no keystrokes. Flycut's solution, which this
copies:

1. `menuWillOpen` fires. If Pastry is not the active application, remember which
   application *is*, **cancel the menu** (activating would close it anyway), and
   activate Pastry.
2. 0.2 s later, reopen the menu with `statusItem.popUpStatusItemMenu(_:)`.
3. `menuWillOpen` fires again, now with Pastry active, so make the search field
   first responder.
4. `menuDidClose`: reactivate the application remembered in step 1, so focus
   goes back where it came from.

Step 2 **must** use `popUpStatusItemMenu(_:)`. Flycut originally replayed the
original mouse event, which stopped working on macOS 27 (upstream `8a24014`) —
that is the single most important fact in this plan, and it is why the spec has
carried a note about it since feature 1.

The user sees the menu flicker once on opening. That is inherent to the
approach and is what Flycut does.

This also makes the `Paster`'s `NSApp.hide(nil)` and its 0.2 s wait genuinely
load-bearing for the first time: with this feature Pastry really is the active
application when a clip is chosen, so focus really does have to be handed back
before the keystroke. Two reviews flagged that step as possibly inert; from here
it is not.

## Global Constraints

- macOS 26.0, Swift 6, zero third-party dependencies, bundle id `de.rvdh.Pastry`.
- Repository `ralph/Pastry`, private, base branch `master`.
- New Swift files go in `Pastry/` and `PastryTests/`; `project.pbxproj` is never edited.
- The Objective-C tree stays untouched until feature 10.

## Scope

In: the search field, live filtering, the activation dance, focus restoration.

Out: the Preferences item and making `displayCount` a preference (**feature 8**);
the bezel (**feature 7**).

## Menu layout

Matching the reference screenshot: the field sits **below** the clip rows.

| Row |
| --- |
| up to `displayCount` matching clip rows, newest first |
| the search field (custom view) |
| separator |
| Clear All, Merge All |
| separator |
| About Pastry, Quit Pastry |

When a query matches nothing, the rows are replaced by a disabled "No matches"
row, so the field never sits alone above a bare separator.

The query resets to empty each time the menu closes: a filter that survived
would silently hide clips the next time the menu opened.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `Pastry/ClipStore.swift` | `search(_:limit:)` |
| `Pastry/StatusMenu.swift` | the field, the query, filtered rows, focusing the field |
| `Pastry/AppDelegate.swift` | the activation dance and focus restoration |
| `PastryTests/ClipStoreTests.swift` | search behaviour |
| `PastryTests/StatusMenuTests.swift` | filtered rows, the no-match row, query reset |

---

## Task 1: Feature branch and draft pull request

- [ ] **Step 1: Branch and push the plan**

```bash
git checkout master && git pull --ff-only
git checkout -b feature/05-menu-search
git add docs/superpowers/plans/2026-11-11-pastry-05-menu-search.md
git commit -m "Add the implementation plan for feature 5

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push -u origin feature/05-menu-search
```

- [ ] **Step 2: Open the draft pull request**

```bash
gh pr create --repo ralph/Pastry --base master --head feature/05-menu-search \
  --draft --title "Feature 5: search field in the menu" --body "$(cat <<'BODY'
Type in the status menu to narrow the clip rows.

A status menu tracks without activating an LSUIElement app, so a search
field in it can never take focus on its own. Pastry does what Flycut
does: cancel the menu, activate, reopen it with popUpStatusItemMenu —
never by replaying the mouse event, which broke on macOS 27 — focus the
field, and hand focus back when the menu closes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY
)"
```

---

## Task 2: `ClipStore.search`

**Files:**
- Modify: `Pastry/ClipStore.swift`
- Modify: `PastryTests/ClipStoreTests.swift`

**Interfaces:**
- `func search(_ query: String, limit: Int) -> [Clip]`
- Returns whole clips, not indices. Menu rows carry their `Clip` since feature 3, so nothing needs to map a row back to a position — the spec's older "original indices" requirement is retired by that change.

- [ ] **Step 1: Write the failing tests**

Add to `PastryTests/ClipStoreTests.swift`:

```swift
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

    /// The menu filters on what the user sees, and a clip's rows show
    /// collapsed whitespace — but the search runs over the real text, so a
    /// phrase broken across a newline still matches what was typed.
    @Test("matches across the original line breaks")
    func searchMatchesAcrossNewlines() {
        let store = ClipStore()
        store.add(Clip.fixture("first line\nsecond line"))
        #expect(store.search("second", limit: 10).count == 1)
    }
```

- [ ] **Step 2: Run them and watch them fail**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)" | head -4
```

Expected: FAIL — no `search` member.

- [ ] **Step 3: Implement it**

Add to `Pastry/ClipStore.swift`, after `clip(at:)`:

```swift
    /// The newest clips whose text contains `query`, case-insensitively.
    ///
    /// Matches the stored text rather than the row's display text, so a phrase
    /// split across a line break still matches, and a long clip matches on
    /// words past the forty characters a row can show.
    func search(_ query: String, limit: Int) -> [Clip] {
        let matches = query.isEmpty
            ? clips
            : clips.filter { $0.text.localizedCaseInsensitiveContains(query) }
        return Array(matches.prefix(limit))
    }
```

- [ ] **Step 4: Run the tests and watch them pass**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | grep -E "error:|✘ Test|Test run with|TEST" | head -6
```

Expected: `** TEST SUCCEEDED **`, 78 tests.

- [ ] **Step 5: Commit**

```bash
git add Pastry/ClipStore.swift PastryTests/ClipStoreTests.swift
git commit -m "Add ClipStore.search

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: The search field in the menu

**Files:**
- Modify: `Pastry/StatusMenu.swift`
- Modify: `PastryTests/StatusMenuTests.swift`

**Interfaces:**
- `StatusMenu` gains `private(set) var query: String`, `func focusSearchField()`, and `func resetQuery()`.
- Rows come from `store.search(query, limit: displayCount)`.
- The field is an `NSSearchField` inside an `NSMenuItem.view`.

- [ ] **Step 1: Write the failing tests**

Add to `PastryTests/StatusMenuTests.swift`:

```swift
    @Test("shows a search field below the clip rows")
    func hasASearchField() {
        let (_, menu) = makeMenu(clips: ["a"])
        let fieldRow = menu.menu.items.firstIndex { $0.view is SearchFieldView }
        let lastClipRow = menu.menu.items.lastIndex { $0.representedObject is Clip }
        #expect(fieldRow != nil)
        #expect(lastClipRow != nil)
        #expect(fieldRow! > lastClipRow!)
    }

    @Test("narrows the rows to clips containing the query")
    func filtersRows() {
        let (_, menu) = makeMenu(clips: ["alpha", "beta", "alpha two"])
        menu.setQueryForTesting("alpha")
        refresh(menu)
        #expect(clipTitles(menu) == ["alpha two", "alpha"])
    }

    @Test("shows a no-match row when the query matches nothing")
    func noMatchRow() {
        let (_, menu) = makeMenu(clips: ["alpha"])
        menu.setQueryForTesting("zzz")
        refresh(menu)
        #expect(clipRows(menu).isEmpty)
        #expect(menu.menu.items.first?.title == "No matches")
        #expect(menu.menu.items.first?.action == nil)
    }

    /// A filter that outlived the menu would silently hide clips the next time
    /// it opened, with nothing on screen explaining why.
    @Test("forgets the query when the menu closes")
    func queryResetsOnClose() {
        let (_, menu) = makeMenu(clips: ["alpha", "beta"])
        menu.setQueryForTesting("alpha")
        refresh(menu)
        #expect(clipTitles(menu) == ["alpha"])

        menu.menuDidClose(menu.menu)
        refresh(menu)

        #expect(menu.query.isEmpty)
        #expect(clipTitles(menu) == ["beta", "alpha"])
    }
```

- [ ] **Step 2: Run them and watch them fail**

Expected: FAIL — no `SearchFieldView`, no `setQueryForTesting`.

- [ ] **Step 3: Implement**

In `Pastry/StatusMenu.swift`, add the view type and wire it up. The field is
built once and reused across rebuilds, because rebuilding it on every open would
throw away the text the user is typing:

```swift
/// Container for the menu's search field. A distinct type so tests and the
/// delegate can find the row without relying on its position.
final class SearchFieldView: NSView {}
```

`StatusMenu` gains:

```swift
    private(set) var query = ""
    private let searchField = NSSearchField()
    private lazy var searchFieldItem: NSMenuItem = {
        let container = SearchFieldView(frame: NSRect(x: 0, y: 0, width: 240, height: 28))
        searchField.frame = NSRect(x: 12, y: 2, width: 216, height: 24)
        searchField.target = self
        searchField.action = #selector(queryChanged(_:))
        searchField.sendsWholeSearchString = false
        searchField.sendsSearchStringImmediately = true
        container.addSubview(searchField)
        let item = NSMenuItem()
        item.view = container
        return item
    }()

    @objc private func queryChanged(_ sender: NSSearchField) {
        query = sender.stringValue
        rebuild()
    }

    /// Called once the application is active and the menu is open again.
    func focusSearchField() {
        searchField.window?.makeFirstResponder(searchField)
    }

    func menuDidClose(_ menu: NSMenu) {
        resetQuery()
    }

    func resetQuery() {
        query = ""
        searchField.stringValue = ""
    }

    /// Test seam: drives the same path the field's action does, without an
    /// event loop to type into.
    func setQueryForTesting(_ text: String) {
        searchField.stringValue = text
        query = text
    }
```

`rebuild()` adds `searchFieldItem` straight after the clip rows, and
`addClipRows()` becomes:

```swift
    private func addClipRows() {
        let clips = store.search(query, limit: displayCount)
        guard !clips.isEmpty else {
            addItem(store.count == 0 ? "No clippings" : "No matches", action: nil)
            return
        }
        for clip in clips { … unchanged … }
    }
```

Note `rebuild()` calls `menu.removeAllItems()`, which would release a freshly
built field; `searchFieldItem` is `lazy` and reused, so the field object and its
text survive every rebuild. Re-adding the same `NSMenuItem` to the menu it was
just removed from is supported.

- [ ] **Step 4: Run the tests and watch them pass**

Expected: `** TEST SUCCEEDED **`, 82 tests.

- [ ] **Step 5: Commit**

```bash
git add Pastry/StatusMenu.swift PastryTests/StatusMenuTests.swift
git commit -m "Filter the menu rows with a search field

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 4: The activation dance

**Files:**
- Modify: `Pastry/AppDelegate.swift`
- Modify: `Pastry/StatusMenu.swift` (forward `menuWillOpen` to a callback)

**Interfaces:**
- `StatusMenu` gains `var onWillOpen: (() -> Bool)?` — returning `false` means "I cancelled the menu, do not continue".

- [ ] **Step 1: Let the delegate intervene when the menu opens**

In `StatusMenu`:

```swift
    /// Returning false means the opening was intercepted and the menu
    /// cancelled, so nothing further should happen this time round.
    var onWillOpen: (() -> Bool)?

    func menuWillOpen(_ menu: NSMenu) {
        guard onWillOpen?() ?? true else { return }
    }
```

- [ ] **Step 2: Implement the dance in `AppDelegate`**

```swift
    /// The application that was active when the menu was opened, so focus can
    /// go back to it afterwards.
    private var previousApp: NSRunningApplication?

    private func menuWillOpen() -> Bool {
        guard !NSApp.isActive else {
            // Second time round: the menu is open and Pastry is active, so the
            // field can finally take focus.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(200))
                self.statusMenu?.focusSearchField()
            }
            return true
        }

        // A status menu tracks without activating the app, and nothing in it
        // can take focus. Cancel, activate, and put it back up — activating
        // would have closed it anyway.
        previousApp = NSWorkspace.shared.frontmostApplication
        statusMenu?.menu.cancelTracking()
        NSApp.activate()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard let item = self.statusItem, let menu = self.statusMenu?.menu else { return }
            // Must be popUpStatusItemMenu. Flycut replayed the original mouse
            // event here and that stopped working on macOS 27 (8a24014).
            item.popUpStatusItemMenu(menu)
        }
        return false
    }

    private func menuDidClose() {
        // Hand focus back to wherever it came from. A paste also hides Pastry,
        // which has the same effect; doing both is harmless and this covers
        // dismissing the menu without choosing anything.
        previousApp?.activate()
        previousApp = nil
    }
```

Wire both into the `StatusMenu` built in `installStatusItem()`.

- [ ] **Step 3: Run the tests**

Expected: `** TEST SUCCEEDED **`, 82 tests. The dance itself is not unit tested — it is four AppKit calls whose behaviour only exists in a running application. It is verified by hand in the next step.

- [ ] **Step 4: Verify by hand — this is the step that matters**

```bash
rm -rf build/dd
xcodebuild -project Pastry.xcodeproj -scheme Pastry -configuration Debug -derivedDataPath build/dd build 2>&1 | tail -2
open build/dd/Build/Products/Debug/Pastry.app
```

Then, with several clips captured:
1. Click the scissors. The menu flickers once and reopens — expected.
2. Type a few characters. The rows narrow as you type.
3. Press Escape. The menu closes and focus returns to the app you were in.
4. Reopen. The field is empty and every clip is listed again.
5. Filter to one clip, choose it, and confirm it pastes into the app you came from.

Step 5 is the one that can regress: with this feature Pastry really is active
when a clip is chosen, so the `Paster`'s focus hand-off is load-bearing for the
first time.

- [ ] **Step 5: Commit and push**

```bash
git add Pastry/AppDelegate.swift Pastry/StatusMenu.swift
git commit -m "Activate so the menu's search field can take focus

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
```

---

## Feature-completion checklist

- [ ] All tests pass locally (82).
- [ ] Typing in the menu narrows the rows.
- [ ] The query is forgotten when the menu closes.
- [ ] Choosing a filtered clip still pastes into the app you came from.
- [ ] Dismissing the menu returns focus without pasting.
- [ ] CI green on the pull request.
- [ ] No Objective-C file modified or deleted.

Then: `/simplify`, mark ready for review, `/code-review medium`, a Codex review, squash merge.

# Pastry Feature 3: Status menu — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the captured clips in the menu-bar menu, with Clear All, Merge All and About, and put a chosen clip on the pasteboard.

**Architecture:** `StatusMenu` grows from a static factory into an object that owns the `NSMenu` and rebuilds its rows from `ClipStore` as `NSMenuDelegate.menuNeedsUpdate(_:)` fires. Rebuilding when the menu opens rather than when the store changes means the menu is always current with no observation machinery, and no work at all while it is closed.

**Tech Stack:** Swift 6, AppKit, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-11-pastry-swift-rewrite-design.md`

## Global Constraints

- macOS 26.0, Swift 6, zero third-party dependencies, bundle id `de.rvdh.Pastry`.
- Repository `ralph/Pastry`, private, base branch `master`.
- New Swift files go in `Pastry/` and `PastryTests/`; `project.pbxproj` is never edited.
- The Objective-C tree stays untouched until feature 10.

## Scope

In: clipping rows, Clear All, Merge All, About, an empty-state row, and selecting a row to put that clip on the pasteboard.

Out, with the feature that owns each:
- Synthesising ⌘V so the clip lands in the frontmost app — **feature 4**. Selecting a row here copies; it does not yet paste.
- The search field — **feature 5**.
- The Preferences item — **feature 8**.
- `displayCount` as a user preference — **feature 8**. Here it is a constructor argument defaulting to 30.

## Menu contents, top to bottom

Matching the reference screenshot of the current installation:

| Row | Behaviour |
| --- | --- |
| Up to `displayCount` clipping rows, newest first | title is the clip's `displayText`; choosing one copies it and moves it to the top |
| *(empty history)* a single disabled "No clippings" row | replaces the rows when the history is empty |
| separator | |
| Clear All | empties the history |
| Merge All | joins the history into one clip at the top |
| separator | |
| About Pastry | standard About panel |
| Quit Pastry (⌘Q) | terminates |

---

## File Structure

| File | Responsibility |
| --- | --- |
| `Pastry/StatusMenu.swift` | Owns the `NSMenu`, rebuilds rows from the store, routes row actions |
| `Pastry/AppDelegate.swift` | Builds the `StatusMenu`, hands selections to the clipboard |
| `PastryTests/StatusMenuTests.swift` | Row contents, capping, empty state, fixed items, selection routing |

---

## Task 1: Feature branch and draft pull request

- [ ] **Step 1: Branch from an up-to-date master**

```bash
git checkout master && git pull --ff-only
git checkout -b feature/03-status-menu
```

- [ ] **Step 2: Commit this plan and push**

```bash
git add docs/superpowers/plans/2026-11-11-pastry-03-status-menu.md
git commit -m "Add the implementation plan for feature 3

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push -u origin feature/03-status-menu
```

- [ ] **Step 3: Open the draft pull request**

```bash
gh pr create --repo ralph/Pastry --base master --head feature/03-status-menu \
  --draft --title "Feature 3: status menu" --body "$(cat <<'BODY'
Lists the captured clips in the menu-bar menu, with Clear All, Merge
All and About. Rows rebuild as the menu opens, so they are always
current and cost nothing while it is closed.

Choosing a row copies that clip to the pasteboard. Pasting it into the
frontmost app is feature 4.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY
)"
```

---

## Task 2: `StatusMenu` builds rows from the store

**Files:**
- Modify: `Pastry/ClipStore.swift`
- Modify: `Pastry/StatusMenu.swift`
- Modify: `PastryTests/ClipStoreTests.swift`
- Modify: `PastryTests/StatusMenuTests.swift`

**Move to top.** Spec §3 locks "move pasted item to top of stack" on, so choosing
a row reorders the history. It must *move* the existing clip, not re-add it:
re-adding through `add(_:)` would stamp it with the current date and lose the
timestamp the bezel shows. `ClipStore` therefore gains:

```swift
    /// Moves an existing clip to the top, keeping its source app and date.
    ///
    /// Choosing a clip is not copying it afresh: the bezel shows when the text
    /// was first copied, so re-adding it through `add(_:)` — which stamps the
    /// current date — would be wrong.
    func moveToTop(at index: Int) {
        guard let clip = clip(at: index) else { return }
        clips.remove(at: index)
        clips.insert(clip, at: 0)
    }
```

with tests in `ClipStoreTests`:

```swift
    @Test("moves a clip to the top keeping its app and date")
    func moveToTopPreservesMetadata() {
        let store = ClipStore()
        store.add(Clip.fixture("older", app: "Safari", at: 100))
        store.add(Clip.fixture("newer", app: "Terminal", at: 200))
        store.moveToTop(at: 1)
        #expect(store.clips.map(\.text) == ["older", "newer"])
        #expect(store.clips.first?.appName == "Safari")
        #expect(store.clips.first?.date == Date(timeIntervalSince1970: 100))
    }

    @Test("ignores a move from an out-of-range index")
    func moveToTopOutOfRange() {
        let store = ClipStore()
        store.add(Clip.fixture("only"))
        store.moveToTop(at: 7)
        #expect(store.clips.map(\.text) == ["only"])
    }
```

**Interfaces:**
- Replaces `enum StatusMenu { static func make() -> NSMenu }` with:
  - `@MainActor final class StatusMenu: NSObject, NSMenuDelegate`
  - `init(store: ClipStore, displayCount: Int = 30, onSelect: @escaping (Clip) -> Void)`
  - `let menu: NSMenu`
  - `func rebuild()` — internal, so tests drive it without opening a menu
- Produces for feature 4: `onSelect` is the single place a chosen clip leaves the menu.
- Produces for feature 5: `rebuild()` is where a search filter will be applied.

- [ ] **Step 1: Write the failing tests**

Replace `PastryTests/StatusMenuTests.swift` entirely:

```swift
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
        #expect(titles(menu).prefix(2) == ["newest", "oldest"])
    }

    @Test("shows each clip's display text, not its raw text")
    func usesDisplayText() {
        let (_, menu) = makeMenu(clips: ["two\nlines"])
        #expect(titles(menu).first == "two lines")
    }

    @Test("lists at most the display count")
    func capsRowsAtDisplayCount() {
        let (_, menu) = makeMenu(clips: ["1", "2", "3", "4", "5"], displayCount: 2)
        #expect(titles(menu).prefix(2) == ["5", "4"])
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
        let titles = titles(menu)
        #expect(titles.contains("Clear All"))
        #expect(titles.contains("Merge All"))
        #expect(titles.contains("About Pastry"))
        #expect(titles.contains("Quit Pastry"))
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

    @Test("rebuilding does not accumulate rows")
    func rebuildIsIdempotent() {
        let (_, menu) = makeMenu(clips: ["a"])
        let before = menu.menu.items.count
        menu.rebuild()
        menu.rebuild()
        #expect(menu.menu.items.count == before)
    }
}
```

- [ ] **Step 2: Run them to make sure they fail**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)" | head -5
```

Expected: FAIL — `StatusMenu` has no such initialiser.

- [ ] **Step 3: Write the implementation**

Replace `Pastry/StatusMenu.swift` entirely:

```swift
import AppKit

/// The menu behind the status item.
///
/// Rows are rebuilt as the menu is about to open rather than whenever the
/// history changes: the menu is then always current, there is nothing to
/// observe, and a capture while the menu is closed costs no UI work at all.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    let menu = NSMenu()

    private let store: ClipStore
    private let displayCount: Int
    private let onSelect: (Clip) -> Void

    init(store: ClipStore, displayCount: Int = 30, onSelect: @escaping (Clip) -> Void) {
        self.store = store
        self.displayCount = displayCount
        self.onSelect = onSelect
        super.init()
        menu.delegate = self
        rebuild()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild()
    }

    func rebuild() {
        menu.removeAllItems()
        addClipRows()
        menu.addItem(.separator())
        addItem("Clear All", #selector(clearAll))
        addItem("Merge All", #selector(mergeAll))
        menu.addItem(.separator())
        addItem("About Pastry", #selector(about))
        menu.addItem(
            withTitle: "Quit Pastry",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
    }

    private func addClipRows() {
        let clips = store.clips.prefix(displayCount)
        guard !clips.isEmpty else {
            let empty = NSMenuItem(title: "No clippings", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }
        for (index, clip) in clips.enumerated() {
            let item = NSMenuItem(
                title: clip.displayText,
                action: #selector(selectClip(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = index
            menu.addItem(item)
        }
    }

    @discardableResult
    private func addItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func selectClip(_ sender: NSMenuItem) {
        // The tag is the row's index at the time the menu was built. A capture
        // can land while the menu is open, so read through the store rather
        // than holding the clip, and tolerate the index being gone.
        guard let clip = store.clip(at: sender.tag) else { return }
        store.moveToTop(at: sender.tag)
        onSelect(clip)
    }

    @objc private func clearAll() {
        store.clear()
    }

    @objc private func mergeAll() {
        store.merge()
    }

    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
```

- [ ] **Step 4: Run the tests and make sure they pass**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | grep -E "error:|✘ Test|Test run with|TEST (SUCCEEDED|FAILED)" | head -8
```

Expected: `** TEST SUCCEEDED **`, 60 tests (48 from feature 2, minus the 1 replaced `StatusMenu` test, plus 11 menu tests and 2 store tests).

- [ ] **Step 5: Commit**

```bash
git add Pastry/StatusMenu.swift PastryTests/StatusMenuTests.swift
git commit -m "Build the status menu from the clip store

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: Wire the menu to the status item

**Files:**
- Modify: `Pastry/AppDelegate.swift`

- [ ] **Step 1: Build the menu with the store and route selection to the pasteboard**

In `AppDelegate`, replace `item.menu = StatusMenu.make()` with a `StatusMenu` built from the store, held in a property, whose `onSelect` writes the chosen clip through the monitor:

```swift
    private(set) var statusMenu: StatusMenu?
```

and in `installStatusItem()`:

```swift
        let statusMenu = StatusMenu(store: store) { [weak self] clip in
            self?.choose(clip)
        }
        item.menu = statusMenu.menu
        self.statusMenu = statusMenu
```

and alongside `record(_:)`:

```swift
    /// Puts a chosen clip on the pasteboard. Feature 4 adds the keystroke that
    /// pastes it into the frontmost application.
    private func choose(_ clip: Clip) {
        monitor?.write(clip.text)
        Log.clipboard.info("copied a clip of \(clip.text.utf8.count) bytes back to the pasteboard")
    }
```

Order matters in `applicationDidFinishLaunching`: `startMonitoring()` must run **before** `installStatusItem()`, because `choose(_:)` needs the monitor to exist.

- [ ] **Step 2: Run the tests**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | grep -E "error:|✘ Test|Test run with|TEST (SUCCEEDED|FAILED)" | head -6
```

Expected: `** TEST SUCCEEDED **`, 60 tests.

- [ ] **Step 3: Verify by hand**

```bash
rm -rf build/dd
xcodebuild -project Pastry.xcodeproj -scheme Pastry -configuration Debug -derivedDataPath build/dd build 2>&1 | tail -2
open build/dd/Build/Products/Debug/Pastry.app
sleep 3
printf 'menu row one' | pbcopy; sleep 1
printf 'menu row two' | pbcopy; sleep 1
```

Then, by hand: click the scissors icon and confirm both clips are listed newest first; choose "menu row one" and confirm `pbpaste` returns it; reopen and confirm it has moved to the top; use Merge All and confirm a combined clip appears; use Clear All and confirm the menu shows "No clippings".

```bash
pbpaste; echo
/usr/bin/log show --info --predicate 'subsystem == "de.rvdh.Pastry"' --last 2m --style compact | tail -5
pkill -f "Pastry.app/Contents/MacOS/Pastry"
```

- [ ] **Step 4: Commit and push**

```bash
git add Pastry/AppDelegate.swift
git commit -m "Show the clip menu on the status item

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
```

---

## Feature-completion checklist

- [ ] All tests pass locally (60).
- [ ] The menu lists clips newest first and caps at the display count.
- [ ] Choosing a row puts that clip on the pasteboard, moves it to the top keeping its original timestamp, and is not re-captured as a new clip.
- [ ] Clear All and Merge All work from the menu.
- [ ] CI green on the pull request.
- [ ] No Objective-C file modified or deleted.

Then: `/simplify`, mark ready for review, `/code-review medium`, a Codex review, squash merge.

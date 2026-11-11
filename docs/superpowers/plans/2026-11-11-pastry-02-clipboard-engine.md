# Pastry Feature 2: Clipboard engine — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture copied text into an in-memory history that deduplicates, caps itself, and never records clips a password manager marked concealed.

**Architecture:** Three units with no UI. `Clip` is the value type. `ClipStore` is the ordered history and the only place list rules live. `ClipboardMonitor` polls `NSPasteboard.changeCount` behind a `ClipboardSource` protocol, so the polling rules are testable against a fake with no real pasteboard. `AppDelegate` composes them and logs each capture, which is how this feature is verified by hand — nothing is on screen until feature 3.

**Tech Stack:** Swift 6, AppKit, OSLog, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-11-pastry-swift-rewrite-design.md`

## Global Constraints

- Minimum deployment target **macOS 26.0**; Swift language mode **6.0**.
- **Zero third-party dependencies.**
- Bundle identifier `de.rvdh.Pastry`; team `89S4HZY343`.
- Repository `ralph/Pastry`, private. Base branch `master`.
- New Swift files go in `Pastry/` and `PastryTests/` — synchronized folder groups pick them up, so `project.pbxproj` is never edited.
- The Objective-C tree stays untouched; it is deleted in feature 10.

## Scope

In: `Clip`, `ClipStore`, `ClipboardSource`, `ClipboardMonitor`, logging, and composition in `AppDelegate`.

Deliberately out, with the feature that owns each:
- Stack-position movement for the bezel — **feature 7**.
- `search(_:limit:)` — **feature 5**, with the menu search field.
- Persistence to disk — **feature 6**. History is in memory only and dies with the process.
- Showing clips anywhere — **feature 3**.
- `rememberCount` as a *preference* — **feature 8**. Here it is a constructor argument defaulting to 40.

## Behaviour this feature locks in

| Rule | Behaviour |
| --- | --- |
| New clip | inserted at index 0 (newest first) |
| Duplicate text | the existing entry is removed and the new one inserted at 0, so the clip moves to the top and carries the *newer* app and timestamp |
| Capacity | trimmed to `rememberCount` (default 40) after every insert, oldest dropped first |
| Empty text | never stored |
| Concealed clip | `org.nspasteboard.ConcealedType` on the pasteboard means the change is consumed but nothing is recorded |
| Pastry's own writes | suppressed, so pasting does not re-record the clip |
| Poll interval | 0.5 s, from a `Task` loop so it keeps polling while a menu is open |

---

## File Structure

| File | Responsibility |
| --- | --- |
| `Pastry/Clip.swift` | The value type and its single-line display text |
| `Pastry/ClipStore.swift` | Ordered history: insert, deduplicate, cap, remove, clear, merge |
| `Pastry/ClipboardSource.swift` | Protocol over the pasteboard plus the `NSPasteboard` adapter |
| `Pastry/ClipboardMonitor.swift` | Polling, change detection, skip rules, self-write suppression |
| `Pastry/Log.swift` | Shared `Logger` instances |
| `Pastry/AppDelegate.swift` | Composes store and monitor, builds `Clip`s with frontmost-app info |
| `PastryTests/ClipTests.swift` | Display text and `Codable` round trip |
| `PastryTests/ClipStoreTests.swift` | Every list rule above |
| `PastryTests/ClipboardMonitorTests.swift` | Every poll rule above, against a fake source |

---

## Task 1: Feature branch and draft pull request

**Files:**
- Commit: `docs/superpowers/plans/2026-11-11-pastry-02-clipboard-engine.md`

**Interfaces:**
- Consumes: `master` at feature 1.
- Produces: branch `feature/02-clipboard-engine`, draft PR against `master`.

- [ ] **Step 1: Branch from an up-to-date master**

```bash
git checkout master && git pull --ff-only
git checkout -b feature/02-clipboard-engine
```

- [ ] **Step 2: Commit this plan and push**

```bash
git add docs/superpowers/plans/2026-11-11-pastry-02-clipboard-engine.md
git commit -m "Add the implementation plan for feature 2

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push -u origin feature/02-clipboard-engine
```

- [ ] **Step 3: Open the draft pull request**

```bash
gh pr create --repo ralph/Pastry --base master --head feature/02-clipboard-engine \
  --draft --title "Feature 2: clipboard engine" --body "$(cat <<'BODY'
Captures copied text into an in-memory history.

`ClipStore` holds the list rules (newest first, duplicates move to the
top, capped at 40). `ClipboardMonitor` polls the pasteboard behind a
protocol so the skip rules are tested against a fake, and never records
a clip marked `org.nspasteboard.ConcealedType`.

Nothing is visible yet — the status menu lists these in feature 3, and
they are not persisted until feature 6.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY
)"
```

---

## Task 2: The `Clip` value type

**Files:**
- Create: `Pastry/Clip.swift`
- Create: `PastryTests/ClipTests.swift`

**Interfaces:**
- Produces: `struct Clip: Equatable, Codable, Sendable` with `let text: String`, `let appName: String?`, `let appBundleURL: URL?`, `let date: Date`, `var displayText: String`, and `static let displayLength = 40`.
- Note for later tasks: `Clip` equality is full-member equality. `ClipStore` deduplicates on `text` alone, **not** on `==`, because a re-copy carries a newer date and possibly a different app.

- [ ] **Step 1: Write the failing tests**

File `PastryTests/ClipTests.swift`:

```swift
import Foundation
import Testing
@testable import Pastry

@Suite("Clip")
struct ClipTests {
    private func clip(_ text: String) -> Clip {
        Clip(text: text, appName: "Safari", appBundleURL: nil, date: Date(timeIntervalSince1970: 0))
    }

    @Test("shows short text unchanged")
    func shortTextUnchanged() {
        #expect(clip("hello world").displayText == "hello world")
    }

    @Test("collapses newlines and tabs into single spaces")
    func collapsesWhitespace() {
        #expect(clip("one\n\ttwo   three").displayText == "one two three")
    }

    @Test("trims surrounding whitespace")
    func trimsEnds() {
        #expect(clip("  padded  ").displayText == "padded")
    }

    @Test("truncates long text to the display length, ellipsis included")
    func truncatesLongText() {
        let display = clip(String(repeating: "a", count: 100)).displayText
        #expect(display.count == Clip.displayLength)
        #expect(display.hasSuffix("…"))
    }

    @Test("leaves text of exactly the display length alone")
    func exactLengthUntouched() {
        let text = String(repeating: "b", count: Clip.displayLength)
        #expect(clip(text).displayText == text)
    }

    @Test("renders whitespace-only text as empty")
    func whitespaceOnly() {
        #expect(clip(" \n\t ").displayText.isEmpty)
    }

    @Test("survives a Codable round trip")
    func codableRoundTrip() throws {
        let original = Clip(
            text: "round trip",
            appName: "Safari",
            appBundleURL: URL(fileURLWithPath: "/Applications/Safari.app"),
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(Clip.self, from: data) == original)
    }
}
```

- [ ] **Step 2: Run them to make sure they fail**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)" | head -5
```

Expected: FAIL — `cannot find 'Clip' in scope`.

- [ ] **Step 3: Write the implementation**

File `Pastry/Clip.swift`:

```swift
import Foundation

/// One entry in the clipboard history.
///
/// `appName` and `appBundleURL` describe where the text was copied from; both
/// are optional because the frontmost application cannot always be identified.
struct Clip: Equatable, Codable, Sendable {
    /// Characters shown per row in the status menu. The bezel shows the full text.
    static let displayLength = 40

    let text: String
    let appName: String?
    let appBundleURL: URL?
    let date: Date

    /// A single-line, length-capped rendering for menu rows.
    var displayText: String {
        let collapsed = text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard collapsed.count > Self.displayLength else { return collapsed }
        return String(collapsed.prefix(Self.displayLength - 1)) + "…"
    }
}
```

- [ ] **Step 4: Run the tests and make sure they pass**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | grep -E "error:|Test run with|TEST (SUCCEEDED|FAILED)" | head -5
```

Expected: `** TEST SUCCEEDED **`, 11 tests (4 from feature 1 plus 7 here).

- [ ] **Step 5: Commit**

```bash
git add Pastry/Clip.swift PastryTests/ClipTests.swift
git commit -m "Add the Clip value type

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: `ClipStore`

**Files:**
- Create: `Pastry/ClipStore.swift`
- Create: `PastryTests/ClipStoreTests.swift`

**Interfaces:**
- Consumes: `Clip` from Task 2.
- Produces, all `@MainActor` on `final class ClipStore`:
  - `init(rememberCount: Int = 40)`
  - `private(set) var clips: [Clip]` — newest first
  - `var rememberCount: Int { get set }` — setting a smaller value trims immediately
  - `var count: Int`, `func clip(at index: Int) -> Clip?`
  - `func add(_ clip: Clip)`, `func remove(at index: Int)`, `func clear()`, `func merge()`
- `clip(at:)` and `remove(at:)` tolerate out-of-range indices, because the menu and bezel act on indices captured before a background capture may have shifted the list.

- [ ] **Step 1: Write the failing tests**

File `PastryTests/ClipStoreTests.swift`:

```swift
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
```

- [ ] **Step 2: Run them to make sure they fail**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)" | head -5
```

Expected: FAIL — `cannot find 'ClipStore' in scope`.

- [ ] **Step 3: Write the implementation**

File `Pastry/ClipStore.swift`:

```swift
import Foundation

/// The clipboard history, newest first.
///
/// Every rule about what the list contains lives here: duplicates move to the
/// top rather than piling up, empty text is never stored, and the list is
/// capped. Nothing in here touches AppKit or the pasteboard, so it is all
/// directly testable.
@MainActor
final class ClipStore {
    private(set) var clips: [Clip] = []

    /// How many clips to keep. Lowering it discards the oldest immediately.
    var rememberCount: Int {
        didSet { trim() }
    }

    init(rememberCount: Int = 40) {
        self.rememberCount = rememberCount
    }

    var count: Int { clips.count }

    func clip(at index: Int) -> Clip? {
        clips.indices.contains(index) ? clips[index] : nil
    }

    /// Inserts at the top. Text already in the history moves up instead of
    /// being duplicated, carrying the newer app and timestamp with it.
    func add(_ clip: Clip) {
        guard !clip.text.isEmpty else { return }
        clips.removeAll { $0.text == clip.text }
        clips.insert(clip, at: 0)
        trim()
    }

    func remove(at index: Int) {
        guard clips.indices.contains(index) else { return }
        clips.remove(at: index)
    }

    func clear() {
        clips.removeAll()
    }

    /// Joins every clip, oldest first, into one new clip at the top.
    func merge() {
        guard !clips.isEmpty else { return }
        let merged = clips.reversed().map(\.text).joined(separator: "\n")
        add(Clip(text: merged, appName: "Pastry", appBundleURL: nil, date: Date()))
    }

    private func trim() {
        guard clips.count > rememberCount else { return }
        clips.removeLast(clips.count - rememberCount)
    }
}
```

- [ ] **Step 4: Run the tests and make sure they pass**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | grep -E "error:|✘ Test|Test run with|TEST (SUCCEEDED|FAILED)" | head -8
```

Expected: `** TEST SUCCEEDED **`, 24 tests.

Note `rememberCount` is a `var` with a `didSet`, so `init` assigning it does **not** fire `trim()` — that is fine, the store starts empty.

- [ ] **Step 5: Commit**

```bash
git add Pastry/ClipStore.swift PastryTests/ClipStoreTests.swift
git commit -m "Add ClipStore, the clipboard history and its list rules

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 4: `ClipboardMonitor`

**Files:**
- Create: `Pastry/ClipboardSource.swift`
- Create: `Pastry/ClipboardMonitor.swift`
- Create: `PastryTests/ClipboardMonitorTests.swift`

**Interfaces:**
- Produces:
  - `protocol ClipboardSource` with `var changeCount: Int { get }`, `var types: [String] { get }`, `func string() -> String?`
  - `struct SystemClipboard: ClipboardSource` wrapping `NSPasteboard.general`
  - `@MainActor final class ClipboardMonitor` with `init(source: ClipboardSource, interval: TimeInterval = 0.5, onCapture: @escaping (String) -> Void)`, `func start()`, `func stop()`, `func poll()`, `func ignoreCurrentContents()`
- `types` is `[String]` rather than `[NSPasteboard.PasteboardType]` so the protocol and its fake stay free of AppKit.
- `poll()` is internal so tests drive it directly instead of waiting on a timer.
- Later features call `ignoreCurrentContents()` immediately after writing to the pasteboard themselves.

- [ ] **Step 1: Write the failing tests**

File `PastryTests/ClipboardMonitorTests.swift`:

```swift
import Foundation
import Testing
@testable import Pastry

/// A pasteboard whose contents the test sets directly.
@MainActor
private final class FakeClipboard: ClipboardSource {
    var changeCount = 0
    var types: [String] = ["public.utf8-plain-text"]
    private var contents: String?

    func string() -> String? { contents }

    /// Mimics a copy: new contents and a bumped change count.
    func copy(_ text: String?, types: [String] = ["public.utf8-plain-text"]) {
        contents = text
        self.types = types
        changeCount += 1
    }
}

@Suite("ClipboardMonitor")
@MainActor
struct ClipboardMonitorTests {
    private func makeMonitor() -> (FakeClipboard, ClipboardMonitor, Box) {
        let clipboard = FakeClipboard()
        let box = Box()
        let monitor = ClipboardMonitor(source: clipboard) { box.captured.append($0) }
        return (clipboard, monitor, box)
    }

    final class Box { var captured: [String] = [] }

    @Test("captures nothing when the pasteboard has not changed")
    func noChangeNoCapture() {
        let (_, monitor, box) = makeMonitor()
        monitor.poll()
        monitor.poll()
        #expect(box.captured.isEmpty)
    }

    @Test("captures newly copied text")
    func capturesNewText() {
        let (clipboard, monitor, box) = makeMonitor()
        clipboard.copy("hello")
        monitor.poll()
        #expect(box.captured == ["hello"])
    }

    @Test("captures one copy only once however often it polls")
    func capturesEachChangeOnce() {
        let (clipboard, monitor, box) = makeMonitor()
        clipboard.copy("hello")
        monitor.poll()
        monitor.poll()
        monitor.poll()
        #expect(box.captured == ["hello"])
    }

    @Test("skips a clip the source marked concealed")
    func skipsConcealedClip() {
        let (clipboard, monitor, box) = makeMonitor()
        clipboard.copy("hunter2", types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"])
        monitor.poll()
        #expect(box.captured.isEmpty)
    }

    @Test("keeps working after a concealed clip")
    func recoversAfterConcealedClip() {
        let (clipboard, monitor, box) = makeMonitor()
        clipboard.copy("hunter2", types: ["org.nspasteboard.ConcealedType"])
        monitor.poll()
        clipboard.copy("ordinary")
        monitor.poll()
        #expect(box.captured == ["ordinary"])
    }

    @Test("skips a change carrying no text")
    func skipsNonText() {
        let (clipboard, monitor, box) = makeMonitor()
        clipboard.copy(nil, types: ["public.png"])
        monitor.poll()
        #expect(box.captured.isEmpty)
    }

    @Test("skips empty text")
    func skipsEmptyText() {
        let (clipboard, monitor, box) = makeMonitor()
        clipboard.copy("")
        monitor.poll()
        #expect(box.captured.isEmpty)
    }

    @Test("ignores the clip Pastry put on the pasteboard itself")
    func ignoresOwnWrite() {
        let (clipboard, monitor, box) = makeMonitor()
        clipboard.copy("pasted by Pastry")
        monitor.ignoreCurrentContents()
        monitor.poll()
        #expect(box.captured.isEmpty)
    }

    @Test("captures the next real copy after one of its own writes")
    func capturesAfterOwnWrite() {
        let (clipboard, monitor, box) = makeMonitor()
        clipboard.copy("pasted by Pastry")
        monitor.ignoreCurrentContents()
        monitor.poll()
        clipboard.copy("typed by the user")
        monitor.poll()
        #expect(box.captured == ["typed by the user"])
    }
}
```

- [ ] **Step 2: Run them to make sure they fail**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)" | head -5
```

Expected: FAIL — `cannot find 'ClipboardSource' in scope`.

- [ ] **Step 3: Write the protocol and the system adapter**

File `Pastry/ClipboardSource.swift`:

```swift
import AppKit

/// The parts of a pasteboard the monitor needs.
///
/// A protocol so the polling rules can be tested against a fake; the real
/// implementation is a thin wrapper over `NSPasteboard.general`. Types are
/// plain strings to keep the protocol, and its fake, free of AppKit.
@MainActor
protocol ClipboardSource {
    var changeCount: Int { get }
    var types: [String] { get }
    func string() -> String?
}

struct SystemClipboard: ClipboardSource {
    private var pasteboard: NSPasteboard { .general }

    var changeCount: Int { pasteboard.changeCount }

    var types: [String] { (pasteboard.types ?? []).map(\.rawValue) }

    func string() -> String? { pasteboard.string(forType: .string) }
}
```

- [ ] **Step 4: Write the monitor**

File `Pastry/ClipboardMonitor.swift`:

```swift
import Foundation

/// Watches the pasteboard and reports newly copied text.
///
/// There is no notification for the system pasteboard, so this polls
/// `changeCount`. The timer runs in `.common` run loop modes: in the default
/// mode it would stop while a menu is open, and a clip arriving then would be
/// missed.
@MainActor
final class ClipboardMonitor {
    /// Marker a source application sets on a clip it considers secret.
    /// Honoured unconditionally — see the design spec's privacy section.
    static let concealedType = "org.nspasteboard.ConcealedType"

    private let source: ClipboardSource
    private let interval: TimeInterval
    private let onCapture: (String) -> Void
    private var lastChangeCount: Int
    private var timer: Timer?

    init(
        source: ClipboardSource,
        interval: TimeInterval = 0.5,
        onCapture: @escaping (String) -> Void
    ) {
        self.source = source
        self.interval = interval
        self.onCapture = onCapture
        self.lastChangeCount = source.changeCount
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.current.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Treats whatever is on the pasteboard right now as already seen. Called
    /// straight after Pastry writes a clip, so pasting does not re-record it.
    func ignoreCurrentContents() {
        lastChangeCount = source.changeCount
    }

    func poll() {
        let changeCount = source.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        guard !source.types.contains(Self.concealedType) else { return }
        guard let text = source.string(), !text.isEmpty else { return }

        onCapture(text)
    }
}
```

- [ ] **Step 5: Run the tests and make sure they pass**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | grep -E "error:|✘ Test|Test run with|TEST (SUCCEEDED|FAILED)" | head -8
```

Expected: `** TEST SUCCEEDED **`, 33 tests.

- [ ] **Step 6: Commit**

```bash
git add Pastry/ClipboardSource.swift Pastry/ClipboardMonitor.swift PastryTests/ClipboardMonitorTests.swift
git commit -m "Add ClipboardMonitor and its pasteboard abstraction

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 5: Compose them in the app and verify live capture

**Files:**
- Create: `Pastry/Log.swift`
- Modify: `Pastry/AppDelegate.swift`

**Interfaces:**
- Consumes: `ClipStore`, `ClipboardMonitor`, `SystemClipboard`, `AppEnvironment`.
- Produces: `AppDelegate.store: ClipStore` and `AppDelegate.monitor: ClipboardMonitor?`, both read by feature 3's menu.

- [ ] **Step 1: Add the logger**

File `Pastry/Log.swift`:

```swift
import OSLog

enum Log {
    static let clipboard = Logger(subsystem: "de.rvdh.Pastry", category: "clipboard")
}
```

- [ ] **Step 2: Compose store and monitor in the delegate**

Replace `Pastry/AppDelegate.swift` with:

```swift
import AppKit

/// Owns the menu-bar status item and the clipboard capture pipeline.
///
/// The status item is AppKit rather than SwiftUI's `MenuBarExtra` by choice: a
/// search field inside a menu needs a custom-view `NSMenuItem`, which
/// `MenuBarExtra(.menu)` cannot express, and the search field arrives in a
/// later feature. See the design spec under docs/superpowers/specs/.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var statusItem: NSStatusItem?
    private(set) var store = ClipStore()
    private(set) var monitor: ClipboardMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppEnvironment.isRunningTests else { return }
        installStatusItem()
        startMonitoring()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = MenuBarIcon.image() {
            item.button?.image = image
        } else {
            // A status item with neither image nor title draws zero width. For
            // an agent app that would look exactly like a failed launch, with
            // no way left to quit it, so fall back to something visible.
            item.button?.title = "Pastry"
        }
        item.menu = StatusMenu.make()
        statusItem = item
    }

    private func startMonitoring() {
        let monitor = ClipboardMonitor(source: SystemClipboard()) { [weak self] text in
            self?.capture(text)
        }
        monitor.start()
        self.monitor = monitor
    }

    private func capture(_ text: String) {
        let app = NSWorkspace.shared.frontmostApplication
        store.add(
            Clip(
                text: text,
                appName: app?.localizedName,
                appBundleURL: app?.bundleURL,
                date: Date()
            )
        )
        Log.clipboard.info(
            "captured \(text.count) characters from \(app?.localizedName ?? "an unknown app", privacy: .public); history now \(self.store.count)"
        )
    }
}
```

The log line deliberately records the clip's **length and source app, never its text** — this is clipboard content, and the unified log is readable by other processes and persists on disk.

- [ ] **Step 3: Run the tests**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | grep -E "error:|✘ Test|Test run with|TEST (SUCCEEDED|FAILED)" | head -8
```

Expected: `** TEST SUCCEEDED **`, 33 tests. The existing `noStatusItemUnderTests` also now covers the monitor not starting under tests.

- [ ] **Step 4: Verify live capture by hand**

```bash
rm -rf build/dd
xcodebuild -project Pastry.xcodeproj -scheme Pastry -configuration Debug -derivedDataPath build/dd build 2>&1 | tail -2
open build/dd/Build/Products/Debug/Pastry.app
sleep 2
printf 'first capture test' | pbcopy
sleep 1
printf 'second capture test' | pbcopy
sleep 1
log show --info --predicate 'subsystem == "de.rvdh.Pastry"' --last 1m --style compact | tail -10
```

Expected: two `captured …` lines, with the history count reaching 2. If no lines appear, the monitor is not running — check that `AppEnvironment.isRunningTests` is false in a normal launch.

- [ ] **Step 5: Verify deduplication live**

```bash
printf 'first capture test' | pbcopy
sleep 1
log show --info --predicate 'subsystem == "de.rvdh.Pastry"' --last 20s --style compact | tail -3
pkill -f "Pastry.app/Contents/MacOS/Pastry"
```

Expected: one further `captured` line whose history count is still **2**, not 3 — re-copying earlier text moved it to the top instead of adding a duplicate.

- [ ] **Step 6: Commit and push**

```bash
git add Pastry/Log.swift Pastry/AppDelegate.swift
git commit -m "Capture the pasteboard into the clip store

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
```

---

## Feature-completion checklist

- [ ] All tests pass locally (33).
- [ ] Live capture verified from the unified log, including deduplication.
- [ ] No clip text is ever written to the log.
- [ ] CI green on the pull request.
- [ ] No Objective-C file modified or deleted.

Then: `/simplify`, mark ready for review, `/code-review medium`, a Codex review, squash merge.


---

## Deviations from this plan during execution

- `ClipboardMonitor` polls from a `Task` loop, not an `NSTimer`. Swift 6 refuses
  to let a nonisolated `deinit` invalidate a non-Sendable `Timer`, and passing
  the timer into a main-actor closure to self-invalidate is a data race. The
  task loop solves the menu-tracking case the `.common` run loop mode existed
  for, and ends itself when the monitor is released. `interval` is a `Duration`
  rather than a `TimeInterval`.
- Live verification found the first `pbcopy` missed when it raced the app's
  launch: the monitor takes its baseline `changeCount` at construction, so a
  copy made before the app finishes launching is correctly treated as
  pre-existing. Verification was repeated against an already-running app.

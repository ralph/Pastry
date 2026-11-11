# Pastry Feature 6: Persistence — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The clipboard history survives quitting and relaunching, and a crash costs at most the last couple of seconds.

**Architecture:** Three small units, none of which touch the screen. `HistoryFile` is the only thing that knows about disk, behind a protocol so every rule is testable against a fake. `HistoryStore` turns clips into JSON and back, and decides what a damaged file means. `DebouncedSaver` collapses a burst of changes into one write. `ClipStore` gains a change notification; `AppDelegate` joins them up.

**Tech Stack:** Swift 6, Foundation, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-11-pastry-swift-rewrite-design.md` §7

## Global Constraints

- macOS 26.0, Swift 6, zero third-party dependencies, bundle id `de.rvdh.Pastry`.
- Repository `ralph/Pastry`, private, base branch `master`.
- New Swift files go in `Pastry/` and `PastryTests/`; `project.pbxproj` is never edited.
- The Objective-C tree stays untouched until feature 10.
- **No screen automation in this feature.** Everything here is verifiable from unit tests and the file on disk.

## Behaviour

| Rule | Behaviour |
| --- | --- |
| Location | `~/Library/Application Support/Pastry/history.json` |
| Format | JSON array of `Clip`, newest first |
| When written | 2 s after the last change, and again on termination |
| Rapid changes | collapse into a single write |
| Missing file | start with an empty history, no error |
| Malformed or unreadable file | start with an empty history, log it, and do **not** delete the file |
| Permissions | `0600` — it holds clipboard contents, so no other account can read it |
| Capacity | whatever `rememberCount` allows; loading trims to it |

Not deleting a damaged file is deliberate: it is the user's clipboard history,
and silently discarding it removes any chance of recovering it by hand.

## Scope

Out, with the feature that owns each: `rememberCount` as a preference
(**feature 8**); the bezel (**feature 7**); iCloud sync (dropped entirely).

---

## File Structure

| File | Responsibility |
| --- | --- |
| `Pastry/HistoryFile.swift` | The disk seam: read, write, where the file lives |
| `Pastry/HistoryStore.swift` | Encode, decode, and what a damaged file means |
| `Pastry/DebouncedSaver.swift` | Collapses a burst of changes into one write |
| `Pastry/ClipStore.swift` | `onChange`, and `load(_:)` to replace contents |
| `Pastry/AppDelegate.swift` | Joins them up; saves on terminate |
| `PastryTests/HistoryStoreTests.swift` | Round trip, missing, malformed, unreadable |
| `PastryTests/DebouncedSaverTests.swift` | Coalescing, flush, cancellation |
| `PastryTests/ClipStoreTests.swift` | `onChange` fires on every mutation; `load` does not |

---

## Task 1: Feature branch and draft pull request

- [ ] **Step 1: Branch and push the plan**

```bash
cd /Users/ralph/code/opensource/Flycut
git checkout master && git pull --ff-only
git checkout -b feature/06-persistence
git add docs/superpowers/plans/2026-11-11-pastry-06-persistence.md
git commit -m "Add the implementation plan for feature 6

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push -u origin feature/06-persistence
```

- [ ] **Step 2: Open the draft pull request**

```bash
cd /Users/ralph/code/opensource/Flycut
gh pr create --repo ralph/Pastry --base master --head feature/06-persistence \
  --draft --title "Feature 6: persistence" --body "$(cat <<'BODY'
The clipboard history survives quitting.

Stored as JSON under Application Support with 0600 permissions, since
it holds clipboard contents. Written 2 seconds after the last change
and again on termination, so a crash costs at most a couple of seconds
rather than the whole session — Flycut saved only on exit.

A missing file starts empty; a damaged one starts empty and is left on
disk rather than deleted, because it is the user's history.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY
)"
```

---

## Task 2: `HistoryFile` and `HistoryStore`

**Interfaces:**
- `protocol HistoryFile: Sendable { func read() throws -> Data?; func write(_ data: Data) throws }` — `read` returns `nil` when the file does not exist, which is not an error.
- `struct DiskHistoryFile: HistoryFile` — `~/Library/Application Support/Pastry/history.json`, created on demand, written atomically at `0600`.
- `struct HistoryStore { init(file: HistoryFile); func load() -> [Clip]; func save(_ clips: [Clip]) }` — `load` never throws: anything unreadable means an empty history.

- [ ] **Step 1: Write the failing tests**

File `PastryTests/HistoryStoreTests.swift`:

```swift
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
        let store = HistoryStore(file: file)
        let clips = [
            Clip.fixture("newest", app: "Safari", at: 200),
            Clip.fixture("oldest", app: "Terminal", at: 100),
        ]

        store.save(clips)

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
```

- [ ] **Step 2: Run them and watch them fail**

```bash
cd /Users/ralph/code/opensource/Flycut
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)" | head -4
```

Expected: FAIL — no `HistoryFile`.

- [ ] **Step 3: Write `Pastry/HistoryFile.swift`**

```swift
import Foundation

/// Where the history lives. A protocol so the store's rules can be tested
/// without touching disk.
protocol HistoryFile: Sendable {
    /// The stored bytes, or `nil` when there is no file yet — which is the
    /// ordinary first-launch case, not an error.
    func read() throws -> Data?
    func write(_ data: Data) throws
}

struct DiskHistoryFile: HistoryFile {
    static let url: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Pastry/history.json")
    }()

    func read() throws -> Data? {
        guard FileManager.default.fileExists(atPath: Self.url.path(percentEncoded: false)) else {
            return nil
        }
        return try Data(contentsOf: Self.url)
    }

    func write(_ data: Data) throws {
        try FileManager.default.createDirectory(
            at: Self.url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // Atomic, so a crash mid-write cannot leave a half-written history.
        try data.write(to: Self.url, options: [.atomic])
        // This file holds clipboard contents; keep it to the owner.
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: Self.url.path(percentEncoded: false)
        )
    }
}
```

- [ ] **Step 4: Write `Pastry/HistoryStore.swift`**

```swift
import Foundation

/// Reads and writes the clipboard history.
///
/// `load()` never throws. Every way of failing — no file, unreadable file,
/// damaged contents — means the same thing to the app: start empty.
struct HistoryStore {
    private let file: HistoryFile

    init(file: HistoryFile = DiskHistoryFile()) {
        self.file = file
    }

    func load() -> [Clip] {
        do {
            guard let data = try file.read() else { return [] }
            return try JSONDecoder().decode([Clip].self, from: data)
        } catch {
            // Deliberately not deleted. It is the user's clipboard history,
            // and leaving it is the only chance of recovering it by hand.
            Log.clipboard.error("could not read the history, starting empty: \(error)")
            return []
        }
    }

    func save(_ clips: [Clip]) {
        do {
            try file.write(try JSONEncoder().encode(clips))
        } catch {
            Log.clipboard.error("could not write the history: \(error)")
        }
    }
}
```

- [ ] **Step 5: Run the tests and watch them pass**

Expected: `** TEST SUCCEEDED **`, 93 tests.

- [ ] **Step 6: Commit**

```bash
cd /Users/ralph/code/opensource/Flycut
git add Pastry/HistoryFile.swift Pastry/HistoryStore.swift PastryTests/HistoryStoreTests.swift
git commit -m "Add the history file and its store

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: `DebouncedSaver`

**Interfaces:**
- `@MainActor final class DebouncedSaver` with `init(delay: Duration = .seconds(2), save: @escaping ([Clip]) -> Void)`, `func schedule(_ clips: [Clip])`, `func flush()`.
- `schedule` replaces any pending save. `flush` writes immediately if one is pending, and is what termination calls.

- [ ] **Step 1: Write the failing tests**

File `PastryTests/DebouncedSaverTests.swift`:

```swift
import Foundation
import Testing
@testable import Pastry

@Suite("DebouncedSaver")
@MainActor
struct DebouncedSaverTests {
    final class Recorder { var saves: [[String]] = [] }

    private func makeSaver(
        delay: Duration = .milliseconds(50),
        recorder: Recorder
    ) -> DebouncedSaver {
        DebouncedSaver(delay: delay) { clips in
            recorder.saves.append(clips.map(\.text))
        }
    }

    @Test("does not save straight away")
    func doesNotSaveImmediately() {
        let recorder = Recorder()
        let saver = makeSaver(recorder: recorder)
        saver.schedule([Clip.fixture("a")])
        #expect(recorder.saves.isEmpty)
    }

    @Test("saves once the delay has passed")
    func savesAfterTheDelay() async throws {
        let recorder = Recorder()
        let saver = makeSaver(recorder: recorder)
        saver.schedule([Clip.fixture("a")])
        try await Task.sleep(for: .milliseconds(200))
        #expect(recorder.saves == [["a"]])
    }

    /// Copying several things in quick succession should cost one write, not
    /// one per clip.
    @Test("collapses a burst into a single save of the latest clips")
    func collapsesABurst() async throws {
        let recorder = Recorder()
        let saver = makeSaver(recorder: recorder)

        saver.schedule([Clip.fixture("a")])
        saver.schedule([Clip.fixture("b")])
        saver.schedule([Clip.fixture("c")])
        try await Task.sleep(for: .milliseconds(200))

        #expect(recorder.saves == [["c"]])
    }

    @Test("flush writes a pending save at once")
    func flushWritesPending() {
        let recorder = Recorder()
        let saver = makeSaver(delay: .seconds(60), recorder: recorder)
        saver.schedule([Clip.fixture("a")])
        saver.flush()
        #expect(recorder.saves == [["a"]])
    }

    /// Termination calls flush; writing twice would be harmless but wasteful,
    /// and a second write after the first is a sign the pending state leaked.
    @Test("flush does not write again once there is nothing pending")
    func flushIsIdempotent() {
        let recorder = Recorder()
        let saver = makeSaver(delay: .seconds(60), recorder: recorder)
        saver.schedule([Clip.fixture("a")])
        saver.flush()
        saver.flush()
        #expect(recorder.saves.count == 1)
    }

    @Test("flush with nothing pending writes nothing")
    func flushWithoutPending() {
        let recorder = Recorder()
        makeSaver(recorder: recorder).flush()
        #expect(recorder.saves.isEmpty)
    }

    @Test("a save after a flush still works")
    func scheduleAfterFlush() {
        let recorder = Recorder()
        let saver = makeSaver(delay: .seconds(60), recorder: recorder)
        saver.schedule([Clip.fixture("a")])
        saver.flush()
        saver.schedule([Clip.fixture("b")])
        saver.flush()
        #expect(recorder.saves == [["a"], ["b"]])
    }
}
```

- [ ] **Step 2: Run them and watch them fail**

- [ ] **Step 3: Write `Pastry/DebouncedSaver.swift`**

```swift
import Foundation

/// Collapses a burst of changes into one write.
///
/// Pasting moves a clip to the top, which is a change; so is every capture.
/// Writing the whole history for each of them would mean a file write per
/// keystroke-sized event, so the last one within the delay wins.
@MainActor
final class DebouncedSaver {
    private let delay: Duration
    private let save: ([Clip]) -> Void
    private var pending: [Clip]?
    private var task: Task<Void, Never>?

    init(delay: Duration = .seconds(2), save: @escaping ([Clip]) -> Void) {
        self.delay = delay
        self.save = save
    }

    func schedule(_ clips: [Clip]) {
        pending = clips
        task?.cancel()
        task = Task { [weak self] in
            guard let delay = self?.delay else { return }
            do {
                try await Task.sleep(for: delay)
            } catch {
                // Superseded by a later change, which owns the write now.
                return
            }
            self?.flush()
        }
    }

    /// Writes a pending save immediately. Called on termination, where there
    /// is no later moment to wait for.
    func flush() {
        task?.cancel()
        task = nil
        guard let clips = pending else { return }
        pending = nil
        save(clips)
    }
}
```

- [ ] **Step 4: Run the tests and watch them pass**

Expected: `** TEST SUCCEEDED **`, 100 tests.

- [ ] **Step 5: Commit**

---

## Task 4: Let `ClipStore` announce changes, and load

**Interfaces:**
- `var onChange: (() -> Void)?` — fires after any mutation that changes the list.
- `func load(_ clips: [Clip])` — replaces the contents, trims to `rememberCount`, and does **not** fire `onChange`, because loading is not a change worth writing back.

- [ ] **Step 1: Write the failing tests**

Add to `PastryTests/ClipStoreTests.swift`:

```swift
    @Test("announces every change to the list", arguments: [
        "add", "remove", "clear", "merge", "moveToTop", "rememberCount",
    ])
    func announcesChanges(mutation: String) {
        let store = ClipStore()
        store.add(Clip.fixture("seed one"))
        store.add(Clip.fixture("seed two"))

        var changes = 0
        store.onChange = { changes += 1 }

        switch mutation {
        case "add": store.add(Clip.fixture("another"))
        case "remove": store.remove(at: 0)
        case "clear": store.clear()
        case "merge": store.merge()
        case "moveToTop": store.moveToTop(Clip.fixture("seed one"))
        case "rememberCount": store.rememberCount = 1
        default: Issue.record("unknown mutation \(mutation)")
        }

        #expect(changes == 1)
    }

    /// Loading is not a change worth writing straight back to disk.
    @Test("does not announce a load")
    func loadIsNotAChange() {
        let store = ClipStore()
        var changes = 0
        store.onChange = { changes += 1 }
        store.load([Clip.fixture("from disk")])
        #expect(changes == 0)
        #expect(store.clips.map(\.text) == ["from disk"])
    }

    @Test("a load is trimmed to the remember count")
    func loadTrims() {
        let store = ClipStore(rememberCount: 2)
        store.load([Clip.fixture("1"), Clip.fixture("2"), Clip.fixture("3")])
        #expect(store.clips.map(\.text) == ["1", "2"])
    }

    @Test("a load replaces whatever was there")
    func loadReplaces() {
        let store = ClipStore()
        store.add(Clip.fixture("existing"))
        store.load([Clip.fixture("from disk")])
        #expect(store.clips.map(\.text) == ["from disk"])
    }
```

- [ ] **Step 2: Implement**

Add `var onChange: (() -> Void)?` and a `private func changed() { onChange?() }` called at the end of `add`, `remove`, `clear`, `merge`, `moveToTop`, and the `rememberCount` `didSet`. `merge` calls `add`, so it must not announce twice — have `merge` rely on `add`'s announcement.

```swift
    func load(_ clips: [Clip]) {
        self.clips = clips
        trim()
    }
```

- [ ] **Step 3: Run the tests**

Expected: `** TEST SUCCEEDED **`, 110 tests.

- [ ] **Step 4: Commit**

---

## Task 5: Wire it into the app

**Files:**
- Modify: `Pastry/AppDelegate.swift`

- [ ] **Step 1: Load at launch, save on change and on termination**

```swift
    private let history = HistoryStore()
    private var saver: DebouncedSaver?
```

In `applicationDidFinishLaunching`, before the status item is installed:

```swift
        store.load(history.load())
        let saver = DebouncedSaver { [history] clips in history.save(clips) }
        store.onChange = { [weak self, weak saver] in
            guard let self, let saver else { return }
            saver.schedule(self.store.clips)
        }
        self.saver = saver
```

and:

```swift
    func applicationWillTerminate(_ notification: Notification) {
        // The pending write has no later moment to wait for.
        saver?.flush()
    }
```

- [ ] **Step 2: Run the tests**

Expected: `** TEST SUCCEEDED **`, 110 tests. `AppEnvironment` still keeps all of this out of test runs.

- [ ] **Step 3: Verify against the real file — no screen needed**

```bash
cd /Users/ralph/code/opensource/Flycut
rm -rf build/dd
xcodebuild -project Pastry.xcodeproj -scheme Pastry -configuration Debug -derivedDataPath build/dd build 2>&1 | tail -2
rm -f ~/Library/Application\ Support/Pastry/history.json

open build/dd/Build/Products/Debug/Pastry.app
sleep 4
printf 'persisted one' | pbcopy; sleep 1
printf 'persisted two' | pbcopy; sleep 3

ls -l@ ~/Library/Application\ Support/Pastry/history.json
python3 -c "import json;print([c['text'] for c in json.load(open('$HOME/Library/Application Support/Pastry/history.json'))])"
```

Expected: the file exists with permissions `-rw-------`, and lists both clips newest first — written by the debounce, without quitting.

```bash
pkill -f "Pastry.app/Contents/MacOS/Pastry"
sleep 2
open build/dd/Build/Products/Debug/Pastry.app
sleep 4
/usr/bin/log show --info --predicate 'subsystem == "de.rvdh.Pastry"' --last 1m --style compact | tail -3
```

Then confirm the history came back by reading the file again — the relaunched
app should not have truncated it.

- [ ] **Step 4: Commit and push**

---

## Feature-completion checklist

- [ ] All tests pass locally (110).
- [ ] The file appears at `~/Library/Application Support/Pastry/history.json` with `0600`.
- [ ] Clips written without quitting, by the debounce.
- [ ] History comes back after a relaunch.
- [ ] A damaged file leaves the app empty but running, and is not deleted.
- [ ] CI green on the pull request.
- [ ] No Objective-C file modified or deleted.

Then: `/simplify`, mark ready for review, `/code-review medium`, a Codex review, squash merge.

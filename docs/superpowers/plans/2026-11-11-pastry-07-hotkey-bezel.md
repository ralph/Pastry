# Pastry Feature 7: Hotkey and bezel — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hold ⌘⇧ and tap V to walk back through the history in an on-screen bezel; release the modifiers and the chosen clip is pasted where you were typing.

**Architecture:** The two genuinely hard parts are isolated so everything else is ordinary. `BezelSelection` is the cursor over the history — pure, no AppKit, exhaustively tested. `BezelKeyMap` turns a keystroke into an action — also pure and exhaustively tested. `HotKey` wraps Carbon registration. `BezelPanel` is the non-activating window, and `BezelController` joins them to the store and the paster.

**Tech Stack:** Swift 6, AppKit, SwiftUI, Carbon, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-11-pastry-swift-rewrite-design.md` §5.6, §5.7, §6.3

## Global Constraints

- macOS 26.0, Swift 6, zero third-party dependencies, bundle id `de.rvdh.Pastry`.
- Repository `ralph/Pastry`, private, base branch `master`.
- New Swift files go in `Pastry/` and `PastryTests/`; `project.pbxproj` is never edited.
- The Objective-C tree stays untouched until feature 10.

## The two things that will fight back

**The panel must take keys without activating the app.** `.nonactivatingPanel`
plus `.borderless` with `canBecomeKey` overridden to `true`. This is the same
class of problem as feature 5's search field, and the lesson from that feature
applies: `NSApp.isActive` is never true for this app, so nothing may depend on
it. Unlike feature 5, the bezel must *not* activate — activating is what would
send the subsequent paste to Pastry instead of the app the user came from.

**Modifier-release is the primary interaction.** The bezel opens while ⌘⇧ are
held and pastes when they are let go. That means watching `flagsChanged` while
the panel is key. If the panel never becomes key, the release is never seen and
the bezel sticks on screen — which is the failure to watch for when verifying.

## Deviation from the spec, recorded

Spec §5.2 puts the stack position in `ClipStore`. This plan puts it in
`BezelSelection`, owned by the bezel. The position is a cursor belonging to one
piece of UI, not a property of the history: the menu does not have one, and
putting it in the store would mean the store growing clamping rules that exist
only for the bezel. `ClipStore` stays a list.

## Scope

In: the hotkey, the bezel, the full key map from spec §6.3, and pasting on
modifier release.

Out: making the hotkey configurable (**feature 9**); the Preferences item that
⌘, opens (**feature 8**) — ⌘, is accepted by the key map now and wired when
Preferences exists.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `Pastry/BezelSelection.swift` | The cursor: where in the history, and how it moves |
| `Pastry/BezelKeyMap.swift` | Keystroke to action, as pure data |
| `Pastry/HotKey.swift` | Carbon registration and teardown |
| `Pastry/BezelPanel.swift` | The non-activating, borderless, key-accepting window |
| `Pastry/BezelView.swift` | SwiftUI contents: source app, time, text, position |
| `Pastry/BezelController.swift` | Joins the panel, the store and the paster |
| `Pastry/AppDelegate.swift` | Builds the controller and registers the hotkey |
| `PastryTests/BezelSelectionTests.swift` | Every movement, clamping at both ends |
| `PastryTests/BezelKeyMapTests.swift` | Every key in spec §6.3 |

---

## Task 1: Feature branch and draft pull request

- [ ] **Step 1: Branch and push the plan**

```bash
cd /Users/ralph/code/opensource/Flycut
git checkout master && git pull --ff-only
git checkout -b feature/07-hotkey-bezel
git add docs/superpowers/plans/2026-11-11-pastry-07-hotkey-bezel.md
git commit -m "Add the implementation plan for feature 7

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push -u origin feature/07-hotkey-bezel
```

- [ ] **Step 2: Open the draft pull request**

```bash
cd /Users/ralph/code/opensource/Flycut
gh pr create --repo ralph/Pastry --base master --head feature/07-hotkey-bezel \
  --draft --title "Feature 7: hotkey and bezel" --body "$(cat <<'BODY'
Hold ⌘⇧ and tap V to walk back through the history in a bezel; release
the modifiers and the chosen clip is pasted where you were typing.

The cursor and the key map are pure types, tested exhaustively. The
panel is non-activating on purpose: activating would send the paste to
Pastry instead of the app the user came from.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY
)"
```

---

## Task 2: `BezelSelection` — the cursor

**Interfaces:**
- `struct BezelSelection: Equatable` with `private(set) var position: Int`, `var count: Int`
- `init(count: Int)` starting at 0
- `mutating func older()`, `newer()`, `tenOlder()`, `tenNewer()`, `first()`, `last()`, `jump(to:)`
- `mutating func clamp()` — after the list shrinks underneath it
- Movement **clamps at both ends**; spec §3 fixes wraparound off.

- [ ] **Step 1: Write the failing tests**

File `PastryTests/BezelSelectionTests.swift`:

```swift
import Testing
@testable import Pastry

@Suite("BezelSelection")
struct BezelSelectionTests {
    @Test("starts at the newest clip")
    func startsAtNewest() {
        #expect(BezelSelection(count: 5).position == 0)
    }

    @Test("older walks towards the end")
    func olderWalksForward() {
        var selection = BezelSelection(count: 3)
        selection.older()
        #expect(selection.position == 1)
        selection.older()
        #expect(selection.position == 2)
    }

    /// Wraparound is off by specification, so the ends are walls.
    @Test("older stops at the oldest clip")
    func olderStopsAtEnd() {
        var selection = BezelSelection(count: 2)
        selection.older()
        selection.older()
        selection.older()
        #expect(selection.position == 1)
    }

    @Test("newer stops at the newest clip")
    func newerStopsAtStart() {
        var selection = BezelSelection(count: 3)
        selection.newer()
        #expect(selection.position == 0)
    }

    @Test("ten at a time clamps rather than overshooting")
    func tenAtATimeClamps() {
        var selection = BezelSelection(count: 5)
        selection.tenOlder()
        #expect(selection.position == 4)
        selection.tenNewer()
        #expect(selection.position == 0)
    }

    @Test("first and last jump to the ends")
    func firstAndLast() {
        var selection = BezelSelection(count: 7)
        selection.last()
        #expect(selection.position == 6)
        selection.first()
        #expect(selection.position == 0)
    }

    @Test("jumps to a position, ignoring one out of range")
    func jumping() {
        var selection = BezelSelection(count: 4)
        selection.jump(to: 2)
        #expect(selection.position == 2)
        selection.jump(to: 9)
        #expect(selection.position == 2)
        selection.jump(to: -1)
        #expect(selection.position == 2)
    }

    /// A clip can be deleted from under the bezel, and capture continues
    /// while it is open.
    @Test("clamps when the history shrinks underneath it")
    func clampsWhenHistoryShrinks() {
        var selection = BezelSelection(count: 5)
        selection.last()
        selection.count = 2
        selection.clamp()
        #expect(selection.position == 1)
    }

    @Test("an empty history leaves no position")
    func emptyHistory() {
        var selection = BezelSelection(count: 0)
        #expect(selection.position == 0)
        selection.older()
        #expect(selection.position == 0)
        selection.clamp()
        #expect(selection.position == 0)
    }
}
```

- [ ] **Step 2: Run them, watch them fail, then implement**

```swift
import Foundation

/// Where the bezel is looking in the history.
///
/// Lives here rather than in `ClipStore` — contrary to the spec's first
/// sketch — because it is one piece of UI's cursor, not a property of the
/// history: the menu has no such position, and the store would otherwise grow
/// clamping rules that exist only for the bezel.
struct BezelSelection: Equatable {
    private(set) var position = 0
    var count: Int

    init(count: Int) {
        self.count = count
    }

    private var lastIndex: Int { max(0, count - 1) }

    mutating func older() { position = min(position + 1, lastIndex) }
    mutating func newer() { position = max(position - 1, 0) }
    mutating func tenOlder() { position = min(position + 10, lastIndex) }
    mutating func tenNewer() { position = max(position - 10, 0) }
    mutating func first() { position = 0 }
    mutating func last() { position = lastIndex }

    mutating func jump(to index: Int) {
        guard (0..<count).contains(index) else { return }
        position = index
    }

    /// Call after the history changes underneath the bezel.
    mutating func clamp() { position = min(position, lastIndex) }
}
```

Expected after this task: `** TEST SUCCEEDED **`, 123 tests.

- [ ] **Step 3: Commit**

---

## Task 3: `BezelKeyMap` — keystrokes as data

**Interfaces:**
- `enum BezelAction: Equatable { case older, newer, jump(Int), first, last, tenOlder, tenNewer, paste, delete, cancel, preferences, ignored }`
- `enum BezelKeyMap { static func action(character: Character?, keyCode: UInt16, hasCommand: Bool, hasShift: Bool, isHotKeyCode: Bool) -> BezelAction }`

Taking the pieces of the event rather than an `NSEvent` keeps this pure and
lets every row of spec §6.3 be a test.

- [ ] **Step 1: Write the failing tests**

Cover every row of the table: the hotkey key alone → older; with shift → newer;
↓ → j → older; ↑ ← k → newer; `1`–`9` → jump to 0–8; `0` → jump to 9;
Home/End → first/last; PageUp/PageDown → tenNewer/tenOlder; Return → paste;
Delete and Backspace → delete; Escape → cancel; ⌘, → preferences; anything
else → ignored.

- [ ] **Step 2: Implement, using the Carbon key codes**

`kVK_Return`, `kVK_Delete`, `kVK_ForwardDelete`, `kVK_Escape`, `kVK_Home`,
`kVK_End`, `kVK_PageUp`, `kVK_PageDown`, `kVK_UpArrow`, `kVK_DownArrow`,
`kVK_LeftArrow`, `kVK_RightArrow`.

Expected after this task: 123 + the key map's tests.

- [ ] **Step 3: Commit**

---

## Task 4: `HotKey` — Carbon registration

**Interfaces:**
- `@MainActor final class HotKey { init?(keyCode: UInt32, modifiers: UInt32, onPress: @escaping () -> Void); func unregister() }`
- `enum HotKeyModifiers { static let commandShift: UInt32 }`

Carbon rather than an `NSEvent` global monitor: registration needs no
Accessibility permission and the key is delivered before other applications
see it.

Not unit tested — it is a registration call into a C API whose behaviour only
exists in a running application. It is verified by hand in Task 7.

- [ ] **Step 1: Implement**

A file-scope registry maps `EventHotKeyID.id` to callbacks, because the Carbon
handler is a C function pointer and cannot capture context. Install the handler
once, lazily.

- [ ] **Step 2: Confirm it builds, then commit**

---

## Task 5: `BezelPanel` and `BezelView`

- [ ] **Step 1: The panel**

```swift
final class BezelPanel: NSPanel {
    // A borderless panel refuses key by default, and without key status the
    // modifier-release that pastes is never seen.
    override var canBecomeKey: Bool { true }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        hidesOnDeactivate = false
        // So it is reachable from whichever Space the user is on.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}
```

Non-activating is the point: activating Pastry would make the subsequent paste
land in Pastry rather than in the application the user came from.

- [ ] **Step 2: The view**

A SwiftUI view taking a `Clip?` and the position, showing the source
application's icon and name with the clip's time as a header, the clip's full
text in the body, and `"\(position + 1) of \(count)"` at the foot. An empty
history shows "Empty". Hosted in an `NSHostingView`.

- [ ] **Step 3: Confirm it builds, then commit**

---

## Task 6: `BezelController`

**Interfaces:**
- `@MainActor final class BezelController { init(store: ClipStore, paste: @escaping (Clip) -> Void, openPreferences: @escaping () -> Void) }`
- `func hotKeyPressed()` — shows the bezel, or advances it if already shown
- `private func handle(_ action: BezelAction)`

Key handling is a local `NSEvent` monitor for `.keyDown` and `.flagsChanged`
installed while the bezel is shown and removed when it hides. On
`.flagsChanged`, when neither command nor shift is held any more, paste.

- [ ] **Step 1: Implement, then commit**

---

## Task 7: Wire up and verify by hand

- [ ] **Step 1: Register the hotkey in `AppDelegate`** and build the controller with the existing `Paster`.

- [ ] **Step 2: Verify — this is the step that matters**

With the app running and several clips captured, and a text editor frontmost:

1. Hold ⌘⇧ and tap V. The bezel appears showing the newest clip.
2. Keep holding and tap V again. It advances to the next older clip.
3. Release ⌘⇧. The bezel disappears and the clip is pasted into the editor.
4. Summon it again and press Escape. It disappears and nothing is pasted.
5. Summon it, press ↓ then ↑, confirm it moves and comes back.
6. Summon it, press Delete, confirm the clip goes and the bezel stays.
7. Confirm Pastry never becomes the active application throughout — the
   editor's title bar should stay focused.

Step 3 is the one that can fail silently: if the panel never became key, the
modifier release is never seen and the bezel stays on screen.

- [ ] **Step 3: Commit and push**

---

## Feature-completion checklist

- [ ] All tests pass locally.
- [ ] ⌘⇧V opens the bezel; repeating V while held walks back.
- [ ] Releasing the modifiers pastes into the app the user came from.
- [ ] Escape dismisses without pasting.
- [ ] The arrows, numbers, Home/End, Page Up/Down, Return and Delete all behave as spec §6.3 says.
- [ ] Pastry never becomes the active application.
- [ ] CI green on the pull request.
- [ ] No Objective-C file modified or deleted.

Then: `/simplify`, mark ready for review, `/code-review medium`, a Codex review, squash merge.

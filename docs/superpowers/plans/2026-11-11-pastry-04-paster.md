# Pastry Feature 4: Paste into the frontmost app — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Choosing a clip pastes it into the application the user was working in, and the Accessibility permission that requires is asked for clearly rather than failing silently.

**Architecture:** `Paster` owns the sequence — write, yield focus, synthesise ⌘V — with each system effect injected as a closure so the ordering and the permission branch are unit tested. The keystroke itself lives in `Keystroke`, a thin wrapper over `CGEvent`.

**Tech Stack:** Swift 6, AppKit, Carbon key codes, ApplicationServices, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-11-pastry-swift-rewrite-design.md`

## Verified before planning

The paste technique was proven end-to-end on this machine (macOS 27.2) before
writing this plan, rather than assumed from Flycut's source:

- `AXIsProcessTrusted()` resolves and reports correctly.
- `kVK_ANSI_V` is 9; `CGEvent(keyboardEventSource:virtualKey:keyDown:)` builds.
- Flags `CGEventFlags.maskCommand.rawValue | 0x000008` → 1048584.
- Posting that pair to `.cghidEventTap` pasted the clipboard into TextEdit.

So the recipe carried over from Flycut still works, including the `0x8` bit that
identifies the left command key for applications that check it.

## Global Constraints

- macOS 26.0, Swift 6, zero third-party dependencies, bundle id `de.rvdh.Pastry`.
- Repository `ralph/Pastry`, private, base branch `master`.
- New Swift files go in `Pastry/` and `PastryTests/`; `project.pbxproj` is never edited.
- The Objective-C tree stays untouched until feature 10.

## Scope

In: pasting a chosen clip into the frontmost application, the Accessibility
permission check and prompt, and behaving sensibly when permission is absent.

Out, with the feature that owns each:
- The bezel and its hotkey — **feature 7**, which will call the same `Paster`.
- Persisting the history — **feature 6**.

## Behaviour

| Situation | Behaviour |
| --- | --- |
| Permission granted | clip is written to the pasteboard, Pastry yields focus, ⌘V is synthesised after a short delay |
| Permission missing | the clip is **still written to the pasteboard**, so ⌘V by hand works; Pastry asks for permission and does not synthesise the keystroke |
| Permission missing, asked before | asked once per launch, not on every paste |

Writing the clip even without permission is deliberate: the useful half of the
feature still works, and a clipboard manager that silently does nothing is worse
than one that copies but does not paste.

The delay between yielding focus and the keystroke is Flycut's 0.2 s. It is
empirical: the keystroke must arrive after the window server has moved focus
back, and there is no completion callback for that.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `Pastry/Keystroke.swift` | Synthesises ⌘V through `CGEvent` |
| `Pastry/Accessibility.swift` | Wraps `AXIsProcessTrusted` and the system prompt |
| `Pastry/Paster.swift` | The sequence, the permission branch, the outcome |
| `Pastry/AppDelegate.swift` | Builds the `Paster`, routes menu selections to it |
| `PastryTests/PasterTests.swift` | Ordering, the permission branch, prompting once |

---

## Task 1: Feature branch and draft pull request

- [ ] **Step 1: Branch and push the plan**

```bash
git checkout master && git pull --ff-only
git checkout -b feature/04-paster
git add docs/superpowers/plans/2026-11-11-pastry-04-paster.md
git commit -m "Add the implementation plan for feature 4

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push -u origin feature/04-paster
```

- [ ] **Step 2: Open the draft pull request**

```bash
gh pr create --repo ralph/Pastry --base master --head feature/04-paster \
  --draft --title "Feature 4: paste into the frontmost app" --body "$(cat <<'BODY'
Choosing a clip now pastes it where the user was typing, instead of only
copying it.

`Paster` writes the clip, yields focus back, and synthesises ⌘V. Without
the Accessibility permission it still writes the clip and asks for
permission once, so ⌘V by hand works and nothing fails silently.

The CGEvent recipe was verified end-to-end on macOS 27 before being
written, including the 0x8 left-command bit carried over from Flycut.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY
)"
```

---

## Task 2: `Keystroke` and `Accessibility`

**Files:**
- Create: `Pastry/Keystroke.swift`
- Create: `Pastry/Accessibility.swift`

**Interfaces:**
- `enum Keystroke { @MainActor static func commandV() }`
- `enum Accessibility { @MainActor static var isTrusted: Bool; @MainActor static func requestTrust() }`

Neither is unit tested: both are single calls into system APIs with no logic of
their own, and both were exercised directly during the probe above. The logic
that *uses* them is injected into `Paster` and fully tested there.

- [ ] **Step 1: Write `Pastry/Keystroke.swift`**

```swift
import Carbon.HIToolbox
import CoreGraphics

/// Synthesises the paste keystroke.
enum Keystroke {
    /// Sends ⌘V to whatever has keyboard focus.
    ///
    /// Posted by **key code**, not by character, so the keystroke is the one
    /// physically at the V position on any keyboard layout — pasting used to
    /// fail on non-QWERTY layouts otherwise.
    ///
    /// The flags carry `0x8` alongside the command mask. That bit identifies
    /// the *left* command key, and some applications check for it rather than
    /// the generic modifier.
    @MainActor
    static func commandV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let v = CGKeyCode(kVK_ANSI_V)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        else { return }

        let flags = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x000008)
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
```

- [ ] **Step 2: Write `Pastry/Accessibility.swift`**

```swift
import ApplicationServices

/// The Accessibility permission, which synthesising a keystroke requires.
enum Accessibility {
    @MainActor
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system's "open System Settings" prompt. macOS shows it at most
    /// once per application per login session however often this is called.
    @MainActor
    static func requestTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
```

- [ ] **Step 3: Confirm it builds**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD" | head -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Pastry/Keystroke.swift Pastry/Accessibility.swift
git commit -m "Add the paste keystroke and the Accessibility check

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: `Paster`

**Files:**
- Create: `Pastry/Paster.swift`
- Create: `PastryTests/PasterTests.swift`

**Interfaces:**
- `enum PasteOutcome: Equatable { case pasted, copiedWithoutPermission }`
- `@MainActor final class Paster` with
  `init(write:yieldFocus:sendPaste:isTrusted:requestTrust:delay:)`, all but
  `write` defaulted to the real system calls, and
  `@discardableResult func paste(_ text: String) async -> PasteOutcome`

- [ ] **Step 1: Write the failing tests**

File `PastryTests/PasterTests.swift`:

```swift
import Foundation
import Testing
@testable import Pastry

@Suite("Paster")
@MainActor
struct PasterTests {
    /// Records what the paster did to the system, in order.
    final class Recorder {
        var steps: [String] = []
        var written: [String] = []
        var trustRequests = 0
    }

    private func makePaster(trusted: Bool, recorder: Recorder) -> Paster {
        Paster(
            write: { text in
                recorder.steps.append("write")
                recorder.written.append(text)
            },
            yieldFocus: { recorder.steps.append("yieldFocus") },
            sendPaste: { recorder.steps.append("sendPaste") },
            isTrusted: { trusted },
            requestTrust: { recorder.trustRequests += 1 },
            delay: .zero
        )
    }

    @Test("writes, yields focus, then sends the keystroke, in that order")
    func pastesInOrder() async {
        let recorder = Recorder()
        let paster = makePaster(trusted: true, recorder: recorder)

        let outcome = await paster.paste("hello")

        #expect(outcome == .pasted)
        #expect(recorder.steps == ["write", "yieldFocus", "sendPaste"])
        #expect(recorder.written == ["hello"])
    }

    @Test("does not ask for permission it already has")
    func doesNotPromptWhenTrusted() async {
        let recorder = Recorder()
        let paster = makePaster(trusted: true, recorder: recorder)
        await paster.paste("hello")
        #expect(recorder.trustRequests == 0)
    }

    /// The useful half still works: the clip is on the pasteboard, so ⌘V by
    /// hand pastes it. Doing nothing at all would be worse.
    @Test("still copies the clip when permission is missing")
    func copiesWithoutPermission() async {
        let recorder = Recorder()
        let paster = makePaster(trusted: false, recorder: recorder)

        let outcome = await paster.paste("hello")

        #expect(outcome == .copiedWithoutPermission)
        #expect(recorder.written == ["hello"])
    }

    @Test("sends no keystroke without permission")
    func sendsNoKeystrokeWithoutPermission() async {
        let recorder = Recorder()
        let paster = makePaster(trusted: false, recorder: recorder)
        await paster.paste("hello")
        #expect(!recorder.steps.contains("sendPaste"))
        #expect(!recorder.steps.contains("yieldFocus"))
    }

    @Test("asks for permission when it is missing")
    func asksForPermission() async {
        let recorder = Recorder()
        let paster = makePaster(trusted: false, recorder: recorder)
        await paster.paste("hello")
        #expect(recorder.trustRequests == 1)
    }

    /// The system dialog is disruptive; one refusal should not mean one dialog
    /// per clip for the rest of the session.
    @Test("asks for permission only once per launch")
    func asksOnlyOnce() async {
        let recorder = Recorder()
        let paster = makePaster(trusted: false, recorder: recorder)
        await paster.paste("one")
        await paster.paste("two")
        await paster.paste("three")
        #expect(recorder.trustRequests == 1)
    }

    /// Permission can be granted in System Settings while Pastry runs, and it
    /// must start working without a relaunch.
    @Test("pastes once permission is granted mid-session")
    func noticesPermissionGrantedLater() async {
        let recorder = Recorder()
        var trusted = false
        let paster = Paster(
            write: { recorder.written.append($0) },
            yieldFocus: { recorder.steps.append("yieldFocus") },
            sendPaste: { recorder.steps.append("sendPaste") },
            isTrusted: { trusted },
            requestTrust: { recorder.trustRequests += 1 },
            delay: .zero
        )

        #expect(await paster.paste("before") == .copiedWithoutPermission)
        trusted = true
        #expect(await paster.paste("after") == .pasted)
        #expect(recorder.steps.contains("sendPaste"))
    }
}
```

- [ ] **Step 2: Run them to make sure they fail**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)" | head -5
```

Expected: FAIL — `cannot find 'Paster' in scope`.

- [ ] **Step 3: Write the implementation**

File `Pastry/Paster.swift`:

```swift
import AppKit

enum PasteOutcome: Equatable {
    case pasted
    /// The clip is on the pasteboard, but Pastry may not synthesise keystrokes.
    case copiedWithoutPermission
}

/// Puts a clip where the user is typing.
///
/// Every system effect is injected, so the order of the steps and the
/// permission branch are testable without touching the real pasteboard,
/// focus or event stream.
@MainActor
final class Paster {
    private let write: (String) -> Void
    private let yieldFocus: () -> Void
    private let sendPaste: () -> Void
    private let isTrusted: () -> Bool
    private let requestTrust: () -> Void
    private let delay: Duration
    private var hasAskedForPermission = false

    init(
        write: @escaping (String) -> Void,
        yieldFocus: @escaping () -> Void = { NSApp.hide(nil) },
        sendPaste: @escaping () -> Void = { Keystroke.commandV() },
        isTrusted: @escaping () -> Bool = { Accessibility.isTrusted },
        requestTrust: @escaping () -> Void = { Accessibility.requestTrust() },
        delay: Duration = .milliseconds(200)
    ) {
        self.write = write
        self.yieldFocus = yieldFocus
        self.sendPaste = sendPaste
        self.isTrusted = isTrusted
        self.requestTrust = requestTrust
        self.delay = delay
    }

    @discardableResult
    func paste(_ text: String) async -> PasteOutcome {
        // The clip goes on the pasteboard either way: without permission the
        // user can still paste it by hand, which is far better than nothing.
        write(text)

        guard isTrusted() else {
            if !hasAskedForPermission {
                hasAskedForPermission = true
                requestTrust()
            }
            Log.clipboard.info("pasted nothing: Accessibility permission is not granted")
            return .copiedWithoutPermission
        }

        // Hiding returns the keyboard to the application the user came from.
        yieldFocus()
        // The window server moves focus asynchronously and reports no
        // completion, so the keystroke waits a moment. 0.2 s is Flycut's value.
        try? await Task.sleep(for: delay)
        sendPaste()
        return .pasted
    }
}
```

- [ ] **Step 4: Run the tests and make sure they pass**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | grep -E "error:|✘ Test|Test run with|TEST (SUCCEEDED|FAILED)" | head -8
```

Expected: `** TEST SUCCEEDED **`, 70 tests (63 plus 7 here).

- [ ] **Step 5: Commit**

```bash
git add Pastry/Paster.swift PastryTests/PasterTests.swift
git commit -m "Add Paster, which puts a clip where the user is typing

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 4: Route menu selections through the paster

**Files:**
- Modify: `Pastry/AppDelegate.swift`

- [ ] **Step 1: Build the paster and use it**

Add a `paster` property built once the monitor exists, since the paster writes
through the monitor so the paste is not captured back:

```swift
    private var paster: Paster?
```

In `startMonitoring()`, after the monitor is assigned:

```swift
        paster = Paster(write: { [weak monitor] text in monitor?.write(text) })
```

and `choose(_:)` becomes:

```swift
    private func choose(_ clip: Clip) {
        store.moveToTop(clip)
        Task { [weak self] in
            guard let self else { return }
            let outcome = await self.paster?.paste(clip.text)
            Log.clipboard.info(
                "chose a clip of \(clip.text.utf8.count) bytes: \(String(describing: outcome), privacy: .public)"
            )
        }
    }
```

- [ ] **Step 2: Run the tests**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry test 2>&1 | grep -E "error:|✘ Test|Test run with|TEST (SUCCEEDED|FAILED)" | head -6
```

Expected: `** TEST SUCCEEDED **`, 70 tests.

- [ ] **Step 3: Verify by hand**

Build, launch, copy two distinct strings, open TextEdit, then click the scissors
icon and choose the older clip. It should appear in TextEdit without any further
keystroke. The first run will show the Accessibility prompt; grant it in System
Settings, then try again.

```bash
rm -rf build/dd
xcodebuild -project Pastry.xcodeproj -scheme Pastry -configuration Debug -derivedDataPath build/dd build 2>&1 | tail -2
open build/dd/Build/Products/Debug/Pastry.app
/usr/bin/log show --info --predicate 'subsystem == "de.rvdh.Pastry"' --last 2m --style compact | tail -5
```

If the permission was granted to an earlier build of the same bundle id and
pasting silently stops working, reset it:

```bash
tccutil reset Accessibility de.rvdh.Pastry
```

- [ ] **Step 4: Commit and push**

```bash
git add Pastry/AppDelegate.swift
git commit -m "Paste a chosen clip into the frontmost application

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
```

---

## Feature-completion checklist

- [ ] All tests pass locally (70).
- [ ] Choosing a clip pastes it into the frontmost app.
- [ ] Without permission, the clip is still copied and the prompt appears once.
- [ ] CI green on the pull request.
- [ ] No Objective-C file modified or deleted.

Then: `/simplify`, mark ready for review, `/code-review medium`, a Codex review, squash merge.

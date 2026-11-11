# Pastry Feature 9: Preferences — Hotkeys — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Hotkeys tab with a key recorder, so the bezel's ⇧⌘V can be changed to whatever the user wants, taking effect without a relaunch.

**Architecture:** The two pieces that can be tested without an event loop are split out and tested exhaustively, as `BezelKeyMap` and `BezelSelection` were in feature 7. `HotKeyRecording` turns a keystroke into a recording outcome. `HotKeyCombination` grows persistence and a display string. `KeyRecorder` is the small `NSView` that feeds real events in, and `AppDelegate` owns re-registration, because it owns the `HotKey`.

**Tech Stack:** Swift 6, AppKit, SwiftUI, Carbon, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-11-pastry-swift-rewrite-design.md` §6.4

## Global Constraints

- macOS 26.0, Swift 6, zero third-party dependencies, bundle id `de.rvdh.Pastry`.
- Repository `ralph/Pastry`, private, base branch `master`.
- New Swift files go in `Pastry/` and `PastryTests/`; `project.pbxproj` is edited only for build settings, never for file references.
- The Objective-C tree stays untouched until feature 10.

## The four things that will fight back

**Registering the new combination must come before unregistering the old.**
Carbon refuses a combination another application already owns, and
`RegisterEventHotKey` is the only way to find that out. If the old one is
released first, a refusal leaves Pastry with no hotkey at all. Two different
combinations never collide with each other, so the new one can be registered
while the old is still live, and the old released only once the new one took.

**`Preferences.onChange` carries no payload.** Every stepper tick in the
General tab calls it. Re-registering a Carbon hotkey on each of those would be
absurd, so the apply path compares the combination against what is actually
registered and does nothing when they match. This is deliberately not solved
by giving `onChange` a payload — feature 8's review argued against adding one
for a single future consumer, and an equality check is smaller than an enum.

**A hotkey with no real modifier is a trap.** ⇧V is just a capital V, so a
combination of shift-plus-a-key would summon the bezel whenever the user typed
that letter, in any application, with no way to type it again. The recorder
requires at least one of ⌘, ⌃ and ⌥. Shift may join them but never stands
alone.

**The recorder must not let Escape through as a hotkey.** Escape is how the
user backs out of recording, and it is also the bezel's dismiss key. It
cancels the recording and is never recorded.

## Decisions the spec does not make

- **The display string is derived from the key code, not stored.** A stored
  label would be a second source of truth that can disagree with the key
  actually registered. `UCKeyTranslate` against the current keyboard layout
  gives the right letter for the user's layout; a table covers the keys that
  have no character (arrows, function keys, space, return).
- **A refused combination reverts.** Rather than storing a hotkey that does
  nothing, the previous one stays registered and the tab says the combination
  is already taken. The app is never left without a working hotkey.
- **Only the bezel hotkey is configurable.** The spec asks for one
  `KeyRecorderView`, and there is one hotkey to record.

## Scope

In: persisting the combination, the display string, the recorder, the Hotkeys
tab, live re-registration, and the refusal path.

Out: a second hotkey of any kind; remapping the keys *inside* the bezel, which
stay as the design spec's table.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `Pastry/HotKeyRecording.swift` | Keystroke to recording outcome, as pure data |
| `Pastry/KeyRecorder.swift` | The `NSView` that captures keys, and its SwiftUI wrapper |
| `Pastry/HotKeysSettingsView.swift` | The Hotkeys tab |
| `PastryTests/HotKeyRecordingTests.swift` | Every row of the recording rules |
| `PastryTests/HotKeyCombinationTests.swift` | Persistence round trip and display strings |

Modified: `Pastry/HotKey.swift` (persistence and `displayString` on the
combination), `Pastry/Preferences.swift` (store the combination, report a
refusal), `Pastry/PreferencesView.swift` (the second tab),
`Pastry/BezelController.swift` (`hotKey` becomes `var`),
`Pastry/AppDelegate.swift` (re-registration), `PastryTests/PreferencesTests.swift`,
and the design spec.

---

## Interfaces

```swift
extension HotKeyCombination {
    init?(defaults: UserDefaults)            // nil when absent or invalid
    func write(to defaults: UserDefaults)
    var displayString: String                // "⇧⌘V"
    var isUsableAsHotKey: Bool               // at least one of ⌘ ⌃ ⌥
}

enum HotKeyRecordingOutcome: Equatable {
    case recorded(HotKeyCombination)
    case cancelled                           // Escape
    case needsAModifier                      // no ⌘ ⌃ ⌥
    case ignored                             // a modifier on its own
}

enum HotKeyRecording {
    static func outcome(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> HotKeyRecordingOutcome
}

// Preferences gains:
var hotKey: HotKeyCombination { get set }
private(set) var hotKeyIsUnavailable: Bool
func reportHotKeyRefused(revertingTo previous: HotKeyCombination)
```

---

## Task 1: Persisting and showing a combination

**Files:**
- Modify: `Pastry/HotKey.swift`
- Test: `PastryTests/HotKeyCombinationTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import AppKit
import Carbon.HIToolbox
import Testing
@testable import Pastry

@Suite("HotKeyCombination")
@MainActor
struct HotKeyCombinationTests {
    @Test("round trips through defaults")
    func roundTrip() {
        let defaults = makeTestDefaults()
        let combination = HotKeyCombination(
            keyCode: UInt16(kVK_ANSI_B),
            modifiers: [.command, .option]
        )
        combination.write(to: defaults)
        #expect(HotKeyCombination(defaults: defaults) == combination)
    }

    @Test("reports nothing stored")
    func nothingStored() {
        #expect(HotKeyCombination(defaults: makeTestDefaults()) == nil)
    }

    /// These are ordinary defaults keys; anything can have written them, and a
    /// combination with no real modifier would fire on an ordinary keystroke.
    @Test("refuses a stored combination that is not usable")
    func refusesUnusableStoredValue() {
        let defaults = makeTestDefaults()
        HotKeyCombination(keyCode: UInt16(kVK_ANSI_V), modifiers: [.shift])
            .write(to: defaults)
        #expect(HotKeyCombination(defaults: defaults) == nil)
    }

    @Test("needs one of command, control or option", arguments: [
        (NSEvent.ModifierFlags([.command]), true),
        (NSEvent.ModifierFlags([.control]), true),
        (NSEvent.ModifierFlags([.option]), true),
        (NSEvent.ModifierFlags([.command, .shift]), true),
        (NSEvent.ModifierFlags([.shift]), false),
        (NSEvent.ModifierFlags([]), false),
        (NSEvent.ModifierFlags([.capsLock]), false),
    ])
    func usability(modifiers: NSEvent.ModifierFlags, usable: Bool) {
        let combination = HotKeyCombination(keyCode: UInt16(kVK_ANSI_V), modifiers: modifiers)
        #expect(combination.isUsableAsHotKey == usable)
    }

    /// The order is the one every Mac menu uses, so the string reads the way
    /// the user has seen a shortcut written their whole life.
    @Test("writes modifiers in the conventional order")
    func modifierOrder() {
        let all = HotKeyCombination(
            keyCode: UInt16(kVK_ANSI_V),
            modifiers: [.command, .shift, .option, .control]
        )
        #expect(all.displayString == "⌃⌥⇧⌘V")
        #expect(HotKeyCombination.commandShiftV.displayString == "⇧⌘V")
    }

    @Test("names keys that have no character", arguments: [
        (kVK_Space, "Space"), (kVK_Return, "Return"), (kVK_Escape, "Escape"),
        (kVK_LeftArrow, "←"), (kVK_F1, "F1"), (kVK_Delete, "Delete"),
    ])
    func specialKeyNames(keyCode: Int, name: String) {
        let combination = HotKeyCombination(
            keyCode: UInt16(keyCode),
            modifiers: [.command]
        )
        #expect(combination.displayString == "⌘" + name)
    }
}
```

- [ ] **Step 2: Run them to watch them fail**

Run: `xcodebuild -project Pastry.xcodeproj -scheme Pastry -destination 'platform=macOS' test`
Expected: FAIL — none of these members exist.

- [ ] **Step 3: Add persistence, usability and the display string**

In `Pastry/HotKey.swift`, extend `HotKeyCombination`:

```swift
extension HotKeyCombination {
    private enum Key {
        static let keyCode = "hotKeyKeyCode"
        static let modifiers = "hotKeyModifiers"
    }

    /// Reads a stored combination, or nil when there is none or it is not
    /// usable. Ordinary defaults keys, so anything can have written them.
    init?(defaults: UserDefaults) {
        guard defaults.object(forKey: Key.keyCode) != nil,
              defaults.object(forKey: Key.modifiers) != nil else { return nil }
        let stored = HotKeyCombination(
            keyCode: UInt16(truncatingIfNeeded: defaults.integer(forKey: Key.keyCode)),
            modifiers: NSEvent.ModifierFlags(
                rawValue: UInt(bitPattern: defaults.integer(forKey: Key.modifiers))
            )
        )
        guard stored.isUsableAsHotKey else { return nil }
        self = stored
    }

    func write(to defaults: UserDefaults) {
        defaults.set(Int(keyCode), forKey: Key.keyCode)
        defaults.set(Int(bitPattern: modifiers.rawValue), forKey: Key.modifiers)
    }

    /// Shift alone does not count: ⇧V is a capital V, so such a hotkey would
    /// fire whenever the user typed that letter, anywhere, and they could
    /// never type it again.
    var isUsableAsHotKey: Bool {
        !modifiers.intersection([.command, .control, .option]).isEmpty
    }

    /// As a Mac shortcut is always written: ⌃⌥⇧⌘ then the key.
    var displayString: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + Self.keyName(for: keyCode)
    }

    /// Keys that carry no character, by key code.
    private static let specialKeyNames: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "Return", kVK_ANSI_KeypadEnter: "Enter",
        kVK_Tab: "Tab", kVK_Escape: "Escape", kVK_Delete: "Delete",
        kVK_ForwardDelete: "⌦", kVK_Home: "Home", kVK_End: "End",
        kVK_PageUp: "Page Up", kVK_PageDown: "Page Down",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12",
    ]

    /// The character the key produces on the keyboard the user is actually
    /// using, rather than a table that assumes ANSI. The key code is a
    /// physical position — the limitation recorded in the design spec — so
    /// asking the current layout is the only way to name it correctly.
    private static func keyName(for keyCode: UInt16) -> String {
        if let special = specialKeyNames[Int(keyCode)] { return special }
        return translated(keyCode)?.uppercased() ?? "Key \(keyCode)"
    }

    private static func translated(_ keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let data = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layout = unsafeBitCast(data, to: CFData.self)
        return (layout as Data).withUnsafeBytes { raw -> String? in
            guard let header = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self)
            else { return nil }
            var deadKeys: UInt32 = 0
            var length = 0
            var characters = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(
                header, keyCode, UInt16(kUCKeyActionDisplay), 0,
                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeys, characters.count, &length, &characters
            )
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: characters, count: length)
        }
    }
}
```

- [ ] **Step 4: Run the tests**

Expected: PASS. If `modifierOrder` fails on `capsLock` or similar, the
`isUsableAsHotKey` intersection is wrong — fix that, not the test.

- [ ] **Step 5: Commit**

```bash
git add Pastry/HotKey.swift PastryTests/HotKeyCombinationTests.swift
git commit -m "Let a hotkey combination persist itself and say its own name"
```

---

## Task 2: The recording rules

**Files:**
- Create: `Pastry/HotKeyRecording.swift`
- Test: `PastryTests/HotKeyRecordingTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import AppKit
import Carbon.HIToolbox
import Testing
@testable import Pastry

@Suite("HotKeyRecording")
struct HotKeyRecordingTests {
    private func outcome(
        _ keyCode: Int,
        _ modifiers: NSEvent.ModifierFlags
    ) -> HotKeyRecordingOutcome {
        HotKeyRecording.outcome(keyCode: UInt16(keyCode), modifiers: modifiers)
    }

    @Test("records a key held with a real modifier")
    func recordsACombination() {
        #expect(
            outcome(kVK_ANSI_B, [.command, .option])
                == .recorded(HotKeyCombination(keyCode: UInt16(kVK_ANSI_B),
                                               modifiers: [.command, .option]))
        )
    }

    /// Escape is how the user backs out, and it is the bezel's dismiss key.
    @Test("escape cancels instead of being recorded")
    func escapeCancels() {
        #expect(outcome(kVK_Escape, []) == .cancelled)
        #expect(outcome(kVK_Escape, [.command]) == .cancelled)
    }

    /// ⇧V is a capital V. Such a hotkey would fire whenever the user typed
    /// that letter and they could never type it again.
    @Test("refuses a combination with no command, control or option")
    func refusesWithoutARealModifier() {
        #expect(outcome(kVK_ANSI_V, []) == .needsAModifier)
        #expect(outcome(kVK_ANSI_V, [.shift]) == .needsAModifier)
    }

    /// Holding ⌘ before pressing the key is how recording always starts, so
    /// the modifier arriving on its own is not an attempt at anything.
    @Test("ignores a modifier pressed on its own", arguments: [
        kVK_Command, kVK_Shift, kVK_Option, kVK_Control,
        kVK_RightCommand, kVK_RightShift, kVK_RightOption, kVK_RightControl,
        kVK_Function, kVK_CapsLock,
    ])
    func ignoresModifiersAlone(keyCode: Int) {
        #expect(outcome(keyCode, [.command]) == .ignored)
    }

    /// The modifiers are filtered to the four that can be registered, so a
    /// stray caps lock or a numeric-pad flag cannot end up in the stored
    /// combination.
    @Test("keeps only the modifiers Carbon can register")
    func filtersModifiers() {
        let result = outcome(kVK_ANSI_B, [.command, .capsLock, .numericPad, .function])
        #expect(
            result == .recorded(HotKeyCombination(keyCode: UInt16(kVK_ANSI_B),
                                                  modifiers: [.command]))
        )
    }
}
```

- [ ] **Step 2: Run them to watch them fail**

Expected: FAIL — `HotKeyRecording` does not exist.

- [ ] **Step 3: Write `Pastry/HotKeyRecording.swift`**

```swift
import AppKit
import Carbon.HIToolbox

/// What a keystroke means while the key recorder is listening.
enum HotKeyRecordingOutcome: Equatable {
    case recorded(HotKeyCombination)
    /// Escape: the user backed out, the old combination stands.
    case cancelled
    /// A key with no ⌘, ⌃ or ⌥ — the recorder says so rather than storing it.
    case needsAModifier
    /// A modifier on its own, which is how every recording starts.
    case ignored
}

/// Turns a keystroke into a recording outcome.
///
/// Takes the pieces of the event rather than an `NSEvent`, so every rule is a
/// plain test with no event loop involved — the same shape as `BezelKeyMap`.
enum HotKeyRecording {
    /// The only modifiers Carbon can register. Caps lock, fn and the
    /// numeric-pad flag ride along on ordinary events and would otherwise end
    /// up stored in a combination that can never be matched again.
    static let registrable: NSEvent.ModifierFlags = [.command, .control, .option, .shift]

    private static let modifierKeyCodes: Set<Int> = [
        kVK_Command, kVK_RightCommand, kVK_Shift, kVK_RightShift,
        kVK_Option, kVK_RightOption, kVK_Control, kVK_RightControl,
        kVK_Function, kVK_CapsLock,
    ]

    static func outcome(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags
    ) -> HotKeyRecordingOutcome {
        if Int(keyCode) == kVK_Escape { return .cancelled }
        if modifierKeyCodes.contains(Int(keyCode)) { return .ignored }

        let combination = HotKeyCombination(
            keyCode: keyCode,
            modifiers: modifiers.intersection(registrable)
        )
        guard combination.isUsableAsHotKey else { return .needsAModifier }
        return .recorded(combination)
    }
}
```

- [ ] **Step 4: Run the tests**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Pastry/HotKeyRecording.swift PastryTests/HotKeyRecordingTests.swift
git commit -m "Add the hotkey recording rules as pure data"
```

---

## Task 3: Preferences holds the combination

**Files:**
- Modify: `Pastry/Preferences.swift`
- Test: `PastryTests/PreferencesTests.swift`

- [ ] **Step 1: Write the failing tests**

Add to `PreferencesTests`:

```swift
@Test("starts at the default hotkey")
func defaultHotKey() {
    let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
    #expect(preferences.hotKey == .commandShiftV)
    #expect(!preferences.hotKeyIsUnavailable)
}

@Test("remembers a recorded hotkey")
func persistsTheHotKey() {
    let defaults = makeTestDefaults()
    let chosen = HotKeyCombination(keyCode: UInt16(kVK_ANSI_B), modifiers: [.control, .option])

    let first = Preferences(defaults: defaults, loginItem: FakeLoginItem())
    first.hotKey = chosen

    let second = Preferences(defaults: defaults, loginItem: FakeLoginItem())
    #expect(second.hotKey == chosen)
}

@Test("announces a new hotkey so it can be registered")
func announcesTheHotKey() {
    let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
    var changes = 0
    preferences.onChange = { changes += 1 }
    preferences.hotKey = HotKeyCombination(keyCode: UInt16(kVK_ANSI_B), modifiers: [.command])
    #expect(changes == 1)
}

/// Re-registering a Carbon hotkey for a value that did not change would be
/// absurd, and the apply path runs on every stepper tick in the General tab.
@Test("stays silent when the hotkey is set to what it already is")
func silentOnAnUnchangedHotKey() {
    let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
    var changes = 0
    preferences.onChange = { changes += 1 }
    let same = preferences.hotKey
    preferences.hotKey = same
    #expect(changes == 0)
}

/// The app is never left without a working hotkey: a refusal puts the old
/// one back and says so.
@Test("reverts and reports a combination another app already owns")
func revertsARefusedHotKey() {
    let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
    let previous = preferences.hotKey
    preferences.hotKey = HotKeyCombination(keyCode: UInt16(kVK_ANSI_B), modifiers: [.command])

    preferences.reportHotKeyRefused(revertingTo: previous)

    #expect(preferences.hotKey == previous)
    #expect(preferences.hotKeyIsUnavailable)
}

/// Otherwise the warning would outlive the combination it was about.
@Test("clears the warning once a different combination is recorded")
func clearsTheWarning() {
    let preferences = Preferences(defaults: makeTestDefaults(), loginItem: FakeLoginItem())
    preferences.reportHotKeyRefused(revertingTo: preferences.hotKey)
    #expect(preferences.hotKeyIsUnavailable)

    preferences.hotKey = HotKeyCombination(keyCode: UInt16(kVK_ANSI_B), modifiers: [.command])
    #expect(!preferences.hotKeyIsUnavailable)
}
```

- [ ] **Step 2: Run them to watch them fail**

Expected: FAIL — `Preferences` has no `hotKey`.

- [ ] **Step 3: Add it to `Preferences`**

Follow the shape the counts already use — a computed property over a private
stored one, so observation fires and nothing takes the property `inout`:

```swift
private var storedHotKey: HotKeyCombination

/// The combination that summons the bezel.
var hotKey: HotKeyCombination {
    get { storedHotKey }
    set {
        guard newValue != storedHotKey else { return }
        storedHotKey = newValue
        // A new choice is not the refused one, whatever happened last time.
        hotKeyIsUnavailable = false
        newValue.write(to: defaults)
        onChange?()
    }
}

/// True when the combination the user asked for was already owned by another
/// application. The previous one stays registered.
private(set) var hotKeyIsUnavailable = false

/// Puts the working combination back after Carbon refused the new one.
///
/// Assigned through the backing property rather than `hotKey`, which would
/// clear the very flag being set and announce a change that is really an
/// undo of one.
func reportHotKeyRefused(revertingTo previous: HotKeyCombination) {
    storedHotKey = previous
    previous.write(to: defaults)
    hotKeyIsUnavailable = true
}
```

In `init`, after the counts: `storedHotKey = HotKeyCombination(defaults: defaults) ?? .commandShiftV`.

- [ ] **Step 4: Run the tests**

Expected: PASS, including the 173 already there.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Store the bezel hotkey in Preferences"
```

---

## Task 4: Re-registering without a relaunch

**Files:**
- Modify: `Pastry/AppDelegate.swift`, `Pastry/BezelController.swift`

- [ ] **Step 1: Make the bezel's combination settable**

In `Pastry/BezelController.swift`, change `private let hotKey: HotKeyCombination`
to `var hotKey: HotKeyCombination`, with a comment:

```swift
/// Settable because feature 9 lets the user change it while the app runs.
/// Everything that reads it — the release check and the key map — reads it
/// each time, so nothing else has to happen when it changes.
var hotKey: HotKeyCombination
```

- [ ] **Step 2: Register the new one before releasing the old**

In `Pastry/AppDelegate.swift`, extract the registration and have
`applyPreferences()` call it:

```swift
/// Registers `combination`, releasing whatever was registered before.
///
/// The new one is registered first: Carbon is the only thing that knows
/// whether another application already owns a combination, and releasing the
/// old one first would mean a refusal left Pastry with no hotkey at all. Two
/// different combinations never collide, so both can be live for an instant.
/// - Returns: whether the new combination took.
@discardableResult
private func registerHotKey(_ combination: HotKeyCombination) -> Bool {
    guard let replacement = HotKey(combination: combination, onPress: { [weak self] in
        self?.hotKeyPressed()
    }) else {
        return false
    }
    hotKey?.unregister()
    hotKey = replacement
    bezel?.hotKey = combination
    return true
}

/// The hotkey's action, which used to live inside the registration closure.
private func hotKeyPressed() {
    // A paste in flight sends ⌘V to whatever window is key once the focus
    // handoff has settled. Showing the bezel now would make it that window,
    // so the keystroke would walk its history instead of pasting and the
    // clip would go nowhere. The wait is 0.2 s.
    guard paster?.isPasting != true else { return }
    bezel?.hotKeyPressed()
}
```

`installBezel()` becomes:

```swift
private func installBezel() {
    let combination = preferences?.hotKey ?? .commandShiftV
    let bezel = BezelController(
        store: store,
        hotKey: combination,
        paste: { [weak self] clip in self?.choose(clip) },
        openPreferences: { [weak self] in self?.showPreferences() }
    )
    self.bezel = bezel

    if !registerHotKey(combination) {
        Log.clipboard.error("the hotkey is unavailable; another app may own it")
        preferences?.reportHotKeyRefused(revertingTo: combination)
    }
}
```

And `applyPreferences()` gains, after the counts:

```swift
// Compared against what is actually registered, because onChange carries no
// payload and fires for every stepper tick in the General tab too.
if preferences.hotKey != bezel?.hotKey {
    let previous = bezel?.hotKey ?? .commandShiftV
    if !registerHotKey(preferences.hotKey) {
        preferences.reportHotKeyRefused(revertingTo: previous)
    }
}
```

- [ ] **Step 3: Build and run the suite**

Expected: PASS. Nothing here is unit-testable — `AppDelegate` early-returns
under tests — so Task 6 is what proves it.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Re-register the hotkey when it changes"
```

---

## Task 5: The recorder and the tab

**Files:**
- Create: `Pastry/KeyRecorder.swift`, `Pastry/HotKeysSettingsView.swift`
- Modify: `Pastry/PreferencesView.swift`

- [ ] **Step 1: Write `Pastry/KeyRecorder.swift`**

```swift
import AppKit
import SwiftUI

/// The control that listens for a combination.
///
/// An `NSView` rather than anything SwiftUI offers, because it has to see key
/// events before they are interpreted — a SwiftUI button would never be told
/// about ⌘Q, and the window's menu equivalents would swallow others. While it
/// is first responder it consumes every key event it is given.
final class KeyRecorderView: NSView {
    var onOutcome: ((HotKeyRecordingOutcome) -> Void)?
    var isRecording = false { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        isRecording = true
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return super.keyDown(with: event) }
        let outcome = HotKeyRecording.outcome(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags
        )
        switch outcome {
        case .ignored:
            return
        case .recorded, .cancelled, .needsAModifier:
            // Anything conclusive ends the recording; the view above decides
            // what to say about it.
            window?.makeFirstResponder(nil)
            onOutcome?(outcome)
        }
    }

    /// Stops ⌘-anything from reaching the window's key equivalents while
    /// recording — otherwise ⌘W would close the window instead of being
    /// recorded.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }
}

struct KeyRecorder: NSViewRepresentable {
    let isRecording: Bool
    let onOutcome: (HotKeyRecordingOutcome) -> Void

    func makeNSView(context: Context) -> KeyRecorderView {
        let view = KeyRecorderView()
        view.onOutcome = onOutcome
        return view
    }

    func updateNSView(_ view: KeyRecorderView, context: Context) {
        view.onOutcome = onOutcome
    }
}
```

- [ ] **Step 2: Write `Pastry/HotKeysSettingsView.swift`**

```swift
import SwiftUI

/// The Hotkeys tab: one recorder, for the combination that summons the bezel.
struct HotKeysSettingsView: View {
    @Bindable var preferences: Preferences
    @State private var isRecording = false
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Summon the bezel") {
                    Button(isRecording ? "Press a combination…" : preferences.hotKey.displayString) {
                        isRecording = true
                    }
                    .background(
                        KeyRecorder(isRecording: isRecording, onOutcome: handle)
                            .frame(width: 0, height: 0)
                    )
                }
            } footer: {
                if let message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                } else if preferences.hotKeyIsUnavailable {
                    Text("Another app is already using that combination.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Hold the modifiers and tap the key to walk back through the history.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func handle(_ outcome: HotKeyRecordingOutcome) {
        isRecording = false
        switch outcome {
        case .recorded(let combination):
            message = nil
            preferences.hotKey = combination
        case .cancelled:
            message = nil
        case .needsAModifier:
            message = "A hotkey needs ⌘, ⌃ or ⌥ — otherwise it would fire as you type."
        case .ignored:
            break
        }
    }
}
```

The zero-sized `KeyRecorder` behind the button is deliberate: the button is
what the user clicks and what shows the combination, and the recorder exists
only to take first responder and consume keys. If this proves awkward in
Task 6, replace the button with a drawn `NSView` — do not add a second way to
start recording.

- [ ] **Step 3: Add the tab**

In `Pastry/PreferencesView.swift`:

```swift
HotKeysSettingsView(preferences: preferences)
    .tabItem { Label("Hotkeys", systemImage: "keyboard") }
```

- [ ] **Step 4: Build and run the suite**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add the Hotkeys tab and its key recorder"
```

---

## Task 6: Check it against the running app

**Files:** none — this is verification.

Nothing in tasks 4 and 5 is unit-testable. Features 5, 7 and 8 each shipped a
bug that only real input found, so this task is not optional. **Ask before
running it: it needs the machine to itself, and `/Applications/Flycut.app`
owns ⇧⌘V and must be quit for the duration and relaunched afterwards.**

- [ ] **Step 1: Record a new combination**

Open Settings › Hotkeys, click the button, press ⌃⌥P. The button shows ⌃⌥P.

- [ ] **Step 2: Check it works immediately**

Without relaunching, hold ⌃⌥ and tap P. The bezel appears and walks. Releasing
pastes. The old ⇧⌘V does nothing.

- [ ] **Step 3: Check the modifier release still pastes**

This is the part most likely to break: the release check reads
`hotKey.modifiers`, which is now a different set. Releasing ⌃⌥ must paste.

- [ ] **Step 4: Check the refusal path**

Record a combination another app owns — ⌘Space is Spotlight's. The tab says
so, and the previous combination still works.

- [ ] **Step 5: Check it survives a relaunch**

Quit and relaunch Pastry. The recorded combination still summons the bezel and
the tab still shows it.

- [ ] **Step 6: Restore**

Set it back to ⇧⌘V, quit the dev build, relaunch Flycut, restore the
clipboard, and delete the test defaults and history.

---

## Task 7: Update the design spec

**Files:**
- Modify: `docs/superpowers/specs/2026-11-11-pastry-swift-rewrite-design.md`

- [ ] **Step 1: Rewrite the Hotkeys paragraph in §6.4**

Record: the usability rule and why shift alone is refused; that the display
string is derived from the key code through the current keyboard layout
rather than stored; that a refused combination reverts rather than being kept;
and that registration happens before the old one is released.

- [ ] **Step 2: Note in §6.3** that the bezel's key table follows the chosen
combination, and that the "⇧ reverses" row stays absent for the reason
feature 7 recorded — which now holds for any combination containing shift.

- [ ] **Step 3: Commit**

```bash
git add docs/
git commit -m "Record what feature 9 settled about the hotkey"
```

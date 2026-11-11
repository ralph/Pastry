# Pastry Feature 8: Preferences — General — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Preferences window with a General tab holding Remember, Display in menu, and Launch at login — reachable from the status menu and from ⌘, in the bezel, with changes taking effect at once.

**Architecture:** `Preferences` holds the values and persists them; it is pure state with a change callback, so it is fully testable without a window. `LoginItem` hides `SMAppService` behind a protocol, because a test must never register a real login item. `PreferencesView` is the SwiftUI form, and `PreferencesWindowController` owns the window Pastry puts it in — Pastry's own window rather than SwiftUI's `Settings` scene, for the reason recorded below.

**Tech Stack:** Swift 6, AppKit, SwiftUI, ServiceManagement, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-11-pastry-swift-rewrite-design.md` §6.4

## Global Constraints

- macOS 26.0, Swift 6, zero third-party dependencies, bundle id `de.rvdh.Pastry`.
- Repository `ralph/Pastry`, private, base branch `master`.
- New Swift files go in `Pastry/` and `PastryTests/`; `project.pbxproj` is never edited.
- The Objective-C tree stays untouched until feature 10.

## The three things that will fight back

**An agent app cannot simply show a window.** The lesson from features 3, 5 and
7 applies again and is the single most likely way this feature breaks: `NSApp`
`.activate()` does not activate an `LSUIElement` app, and `NSApp.isActive` is
never true for one. The Preferences window must come up in front and take
keyboard focus, so it needs `activate(ignoringOtherApps: true)` and
`makeKeyAndOrderFront`. Nothing in this feature may test `NSApp.isActive`.

**A test must never register a real login item.** `SMAppService.mainApp
.register()` writes to the user's actual login items and survives the test
run. Every path to it goes through the `LoginItem` protocol, and the real
implementation is constructed in exactly one place: `AppDelegate`, which
already early-returns under `AppEnvironment.isRunningTests`.

**The system owns the login-item state, not `UserDefaults`.** The user can
turn Pastry off in System Settings, and a cached boolean would then lie. The
toggle reads `SMAppService.mainApp.status` every time it is shown. The only
thing stored is whether the default has been applied once, so turning it off
does not get undone on the next launch.

## Deviation from the spec, recorded

Spec §6.4 says "a SwiftUI `Settings` scene with two tabs". This plan keeps
`Settings { EmptyView() }` as the app's placeholder scene and builds the real
window itself, as an `NSWindow` hosting `PreferencesView`.

Two reasons. The `Settings` scene's window can only be summoned from AppKit
code through `NSApp.sendAction(Selector(("showSettingsWindow:")), …)` — a
selector that is not API, has already been renamed once, and would be
discovered broken by a user rather than by a test. And feature 9's key
recorder has to capture keystrokes inside this window, which means controlling
the window and its responder chain; that is not available through the
`Settings` scene.

## Decisions the spec does not make

- **Bounds: 1…99 for both counts.** The spec gives defaults, not limits. Zero
  for Remember means a clipboard manager that remembers nothing, which is a
  way to lose work rather than a setting; 99 is Flycut's stepper ceiling.
- **The two counts stay independent.** A Display count above the Remember
  count is harmless — the menu shows what exists — so it is not worth a
  constraint that would silently move a number the user just typed.

## Scope

In: the Preferences window, the General tab, the two counts taking effect
immediately, launch at login, and the two ways in (status menu, ⌘, in the
bezel).

Out: the Hotkeys tab and the key recorder (**feature 9**); the window gains a
second tab there.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `Pastry/Preferences.swift` | The values, persisted, with a change callback |
| `Pastry/LoginItem.swift` | Launch at login, behind a protocol |
| `Pastry/PreferencesView.swift` | The General tab, as SwiftUI |
| `Pastry/PreferencesWindowController.swift` | The window, and bringing it to front |
| `PastryTests/PreferencesTests.swift` | Values, persistence, clamping, callbacks |
| `PastryTests/LoginItemTests.swift` | The first-run default and the toggle |
| `PastryTests/PreferencesWindowControllerTests.swift` | One window, reused |

Modified: `Pastry/AppDelegate.swift` (own the preferences, wire both counts),
`Pastry/StatusMenu.swift` (a Preferences item; `displayCount` becomes `var`),
`Pastry/BezelKeyMap.swift` (⌘, returns `.preferences` again),
`Pastry/BezelController.swift` (an `openPreferences` callback),
`PastryTests/BezelKeyMapTests.swift`, `PastryTests/StatusMenuTests.swift`,
and the design spec.

---

## Interfaces

Produced by this feature, relied on by feature 9:

```swift
@MainActor @Observable final class Preferences {
    init(defaults: UserDefaults = .standard, loginItem: LoginItem)
    var rememberCount: Int      // 1...99, default 40
    var displayCount: Int       // 1...99, default 30
    var launchAtLogin: Bool     // read from the system, not from defaults
    var loginItemNeedsApproval: Bool
    var onChange: (() -> Void)?
    func applyDefaultLoginItemOnce()
}

@MainActor protocol LoginItem {
    var isEnabled: Bool { get }
    var needsApproval: Bool { get }
    func setEnabled(_ enabled: Bool)
    func openSystemSettings()
}

@MainActor final class PreferencesWindowController {
    init(preferences: Preferences)
    func show()
}
```

---

## Task 1: Preferences, the values

**Files:**
- Create: `Pastry/Preferences.swift`
- Test: `PastryTests/PreferencesTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import Pastry

/// A login item that records what it was told, so no test touches the real
/// one. Registering a real login item would outlive the test run.
@MainActor
final class FakeLoginItem: LoginItem {
    var isEnabled = false
    var needsApproval = false
    private(set) var changes: [Bool] = []
    var openedSystemSettings = false

    func setEnabled(_ enabled: Bool) {
        changes.append(enabled)
        isEnabled = enabled
    }

    func openSystemSettings() { openedSystemSettings = true }
}

@Suite("Preferences")
@MainActor
struct PreferencesTests {
    /// A suite of its own per test, so nothing reaches the real defaults and
    /// one test cannot see another's writes.
    private func makeDefaults() -> UserDefaults {
        let suite = "de.rvdh.Pastry.tests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test("starts at the documented defaults")
    func defaultsAreTheSpecifiedOnes() {
        let preferences = Preferences(defaults: makeDefaults(), loginItem: FakeLoginItem())
        #expect(preferences.rememberCount == 40)
        #expect(preferences.displayCount == 30)
    }

    @Test("remembers what it was set to")
    func persistsAcrossInstances() {
        let defaults = makeDefaults()
        let first = Preferences(defaults: defaults, loginItem: FakeLoginItem())
        first.rememberCount = 12
        first.displayCount = 7

        let second = Preferences(defaults: defaults, loginItem: FakeLoginItem())
        #expect(second.rememberCount == 12)
        #expect(second.displayCount == 7)
    }

    /// A stepper cannot produce these, but a typed field and a defaults write
    /// from the command line both can.
    @Test("clamps a count to the allowed range", arguments: [
        (0, 1), (-5, 1), (100, 99), (1, 1), (99, 99),
    ])
    func clampsCounts(given: Int, expected: Int) {
        let preferences = Preferences(defaults: makeDefaults(), loginItem: FakeLoginItem())
        preferences.rememberCount = given
        preferences.displayCount = given
        #expect(preferences.rememberCount == expected)
        #expect(preferences.displayCount == expected)
    }

    /// Defaults written outside the app are not validated on the way in.
    @Test("clamps a stored value that is out of range")
    func clampsWhatItReads() {
        let defaults = makeDefaults()
        defaults.set(10_000, forKey: "rememberCount")
        let preferences = Preferences(defaults: defaults, loginItem: FakeLoginItem())
        #expect(preferences.rememberCount == 99)
    }

    @Test("announces a change so the app can apply it")
    func announcesChanges() {
        let preferences = Preferences(defaults: makeDefaults(), loginItem: FakeLoginItem())
        var changes = 0
        preferences.onChange = { changes += 1 }

        preferences.rememberCount = 10
        preferences.displayCount = 5
        #expect(changes == 2)
    }

    /// Otherwise every keystroke in a stepper would re-trim the history and
    /// schedule a write of it.
    @Test("stays silent when a value is set to what it already is")
    func staysSilentWhenNothingChanges() {
        let preferences = Preferences(defaults: makeDefaults(), loginItem: FakeLoginItem())
        var changes = 0
        preferences.onChange = { changes += 1 }

        preferences.rememberCount = preferences.rememberCount
        preferences.displayCount = preferences.displayCount
        #expect(changes == 0)
    }
}
```

- [ ] **Step 2: Run them to watch them fail**

Run: `xcodebuild -project Pastry.xcodeproj -scheme Pastry -destination 'platform=macOS' test`
Expected: FAIL — `Preferences` and `LoginItem` do not exist.

- [ ] **Step 3: Write `Pastry/LoginItem.swift`**

```swift
import ServiceManagement

/// Whether Pastry starts when the user logs in.
///
/// Behind a protocol because the real implementation writes to the user's
/// actual login items and the change outlives the process — a test must never
/// reach it. The real one is constructed in `AppDelegate` only, which already
/// does nothing under a test run.
@MainActor
protocol LoginItem {
    var isEnabled: Bool { get }
    /// True when macOS has the registration but the user has not approved it
    /// yet, which it answers with instead of an error.
    var needsApproval: Bool { get }
    func setEnabled(_ enabled: Bool)
    func openSystemSettings()
}

/// The real one, over `SMAppService`.
@MainActor
struct SystemLoginItem: LoginItem {
    private var service: SMAppService { .mainApp }

    // Read from the system every time rather than cached: the user can turn
    // Pastry off in System Settings, and a remembered boolean would then
    // show a toggle that disagrees with what actually happens at login.
    var isEnabled: Bool { service.status == .enabled }
    var needsApproval: Bool { service.status == .requiresApproval }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            // Nothing can be done from here, and the toggle reads the real
            // status back, so a failure shows itself rather than being
            // asserted away.
            Log.clipboard.error(
                "could not \(enabled ? "enable" : "disable", privacy: .public) launch at login: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
```

- [ ] **Step 4: Write `Pastry/Preferences.swift`**

```swift
import Foundation
import Observation

/// Everything the user can change.
///
/// The counts live in `UserDefaults`; launch at login does not, because the
/// system owns that state and the user can change it from System Settings.
@MainActor
@Observable
final class Preferences {
    /// Below one, a clipboard manager remembers nothing, which is a way to
    /// lose work rather than a setting. Ninety-nine is Flycut's ceiling.
    static let countRange = 1...99

    private let defaults: UserDefaults
    private let loginItem: LoginItem

    /// Called when a stored value actually changed, so the app can apply it.
    var onChange: (() -> Void)?

    var rememberCount: Int {
        didSet { store(rememberCount, oldValue, forKey: Key.rememberCount) }
    }

    var displayCount: Int {
        didSet { store(displayCount, oldValue, forKey: Key.displayCount) }
    }

    var launchAtLogin: Bool {
        get { loginItem.isEnabled }
        set { loginItem.setEnabled(newValue) }
    }

    var loginItemNeedsApproval: Bool { loginItem.needsApproval }

    init(defaults: UserDefaults = .standard, loginItem: LoginItem) {
        self.defaults = defaults
        self.loginItem = loginItem
        defaults.register(defaults: [
            Key.rememberCount: 40,
            Key.displayCount: 30,
        ])
        // Clamped on the way in too: these are plain defaults keys and
        // anything can have written them.
        rememberCount = Self.clamp(defaults.integer(forKey: Key.rememberCount))
        displayCount = Self.clamp(defaults.integer(forKey: Key.displayCount))
    }

    /// Turns launch at login on the first time Pastry runs, and never again.
    ///
    /// Without the stored marker, a user who turned it off would find it back
    /// on at the next launch.
    func applyDefaultLoginItemOnce() {
        guard !defaults.bool(forKey: Key.appliedDefaultLoginItem) else { return }
        defaults.set(true, forKey: Key.appliedDefaultLoginItem)
        loginItem.setEnabled(true)
    }

    func openLoginItemSettings() { loginItem.openSystemSettings() }

    private func store(_ value: Int, _ oldValue: Int, forKey key: String) {
        let clamped = Self.clamp(value)
        if clamped != value {
            // Re-entering didSet with the clamped value, which then matches
            // and falls through to the comparison below.
            if key == Key.rememberCount { rememberCount = clamped } else { displayCount = clamped }
            return
        }
        guard clamped != oldValue else { return }
        defaults.set(clamped, forKey: key)
        onChange?()
    }

    private static func clamp(_ value: Int) -> Int {
        min(max(value, countRange.lowerBound), countRange.upperBound)
    }

    private enum Key {
        static let rememberCount = "rememberCount"
        static let displayCount = "displayCount"
        static let appliedDefaultLoginItem = "appliedDefaultLoginItem"
    }
}
```

- [ ] **Step 5: Run the tests**

Run: `xcodebuild -project Pastry.xcodeproj -scheme Pastry -destination 'platform=macOS' test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Pastry/Preferences.swift Pastry/LoginItem.swift PastryTests/PreferencesTests.swift
git commit -m "Add Preferences, the settings values behind a login-item protocol"
```

---

## Task 2: The first-run login item

**Files:**
- Test: `PastryTests/LoginItemTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import Pastry

@Suite("Launch at login")
@MainActor
struct LoginItemTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "de.rvdh.Pastry.tests.\(UUID().uuidString)")!
    }

    @Test("turns itself on the first time Pastry runs")
    func onByDefault() {
        let item = FakeLoginItem()
        let preferences = Preferences(defaults: makeDefaults(), loginItem: item)
        preferences.applyDefaultLoginItemOnce()
        #expect(item.changes == [true])
        #expect(preferences.launchAtLogin)
    }

    /// The whole point of the stored marker: a user who turns it off has to
    /// find it still off next time.
    @Test("does not turn itself back on after the user turned it off")
    func respectsTheUsersChoice() {
        let defaults = makeDefaults()
        let item = FakeLoginItem()

        let first = Preferences(defaults: defaults, loginItem: item)
        first.applyDefaultLoginItemOnce()
        first.launchAtLogin = false

        let second = Preferences(defaults: defaults, loginItem: item)
        second.applyDefaultLoginItemOnce()

        #expect(item.changes == [true, false])
        #expect(!second.launchAtLogin)
    }

    /// Cached, it would disagree with the system the moment the user changed
    /// it in System Settings.
    @Test("reports what the system says, not what it was last told")
    func readsTheSystemState() {
        let item = FakeLoginItem()
        let preferences = Preferences(defaults: makeDefaults(), loginItem: item)

        item.isEnabled = true
        #expect(preferences.launchAtLogin)
        item.isEnabled = false
        #expect(!preferences.launchAtLogin)
    }

    @Test("surfaces a registration still waiting for approval")
    func surfacesApproval() {
        let item = FakeLoginItem()
        item.needsApproval = true
        let preferences = Preferences(defaults: makeDefaults(), loginItem: item)
        #expect(preferences.loginItemNeedsApproval)
    }
}
```

- [ ] **Step 2: Run them**

Expected: PASS against Task 1's implementation. If any fail, the implementation
is wrong, not the test — fix `Preferences`.

- [ ] **Step 3: Commit**

```bash
git add PastryTests/LoginItemTests.swift
git commit -m "Cover the first-run login item and the system's own state"
```

---

## Task 3: The window and the General tab

**Files:**
- Create: `Pastry/PreferencesView.swift`, `Pastry/PreferencesWindowController.swift`
- Test: `PastryTests/PreferencesWindowControllerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import AppKit
import Testing
@testable import Pastry

@Suite("PreferencesWindowController")
@MainActor
struct PreferencesWindowControllerTests {
    private func makeController() -> PreferencesWindowController {
        let defaults = UserDefaults(suiteName: "de.rvdh.Pastry.tests.\(UUID().uuidString)")!
        return PreferencesWindowController(
            preferences: Preferences(defaults: defaults, loginItem: FakeLoginItem())
        )
    }

    /// Showing it twice must not leave two Preferences windows on screen.
    @Test("reuses its window")
    func reusesItsWindow() {
        let controller = makeController()
        controller.show()
        let first = controller.window
        controller.show()
        #expect(first === controller.window)
        #expect(controller.window?.isVisible == true)
        controller.window?.close()
    }

    @Test("gives the window a title and a close button")
    func looksLikeAWindow() {
        let controller = makeController()
        controller.show()
        #expect(controller.window?.title == "Pastry Settings")
        #expect(controller.window?.styleMask.contains(.closable) == true)
        controller.window?.close()
    }
}
```

- [ ] **Step 2: Run it to watch it fail**

Expected: FAIL — `PreferencesWindowController` does not exist.

- [ ] **Step 3: Write `Pastry/PreferencesView.swift`**

```swift
import SwiftUI

/// The Preferences window's content. One tab today; feature 9 adds Hotkeys.
struct PreferencesView: View {
    @Bindable var preferences: Preferences

    var body: some View {
        TabView {
            GeneralSettingsView(preferences: preferences)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 420)
        .padding(20)
    }
}

struct GeneralSettingsView: View {
    @Bindable var preferences: Preferences

    var body: some View {
        Form {
            // Stepper rather than a free text field: the range is the whole
            // validation, and a stepper cannot express a value outside it.
            Stepper(
                value: $preferences.rememberCount,
                in: Preferences.countRange
            ) {
                Text("Remember \(preferences.rememberCount) clippings")
            }

            Stepper(
                value: $preferences.displayCount,
                in: Preferences.countRange
            ) {
                Text("Display \(preferences.displayCount) in the menu")
            }

            Section {
                Toggle("Launch Pastry at login", isOn: $preferences.launchAtLogin)
                if preferences.loginItemNeedsApproval {
                    // macOS answers register() with "waiting for approval"
                    // rather than an error, and nothing happens at login
                    // until the user allows it.
                    HStack(spacing: 8) {
                        Text("Waiting for your approval in System Settings.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button("Open…") { preferences.openLoginItemSettings() }
                            .buttonStyle(.link)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
```

- [ ] **Step 4: Write `Pastry/PreferencesWindowController.swift`**

```swift
import AppKit
import SwiftUI

/// Pastry's own Preferences window.
///
/// Not SwiftUI's `Settings` scene: the only way to summon that from AppKit is
/// `NSApp.sendAction(Selector(("showSettingsWindow:")), …)`, a selector that
/// is not API and has already been renamed once. Feature 9's key recorder
/// also needs this window's responder chain, which the scene does not hand
/// out. The app keeps an empty `Settings` scene only because `App` needs one.
@MainActor
final class PreferencesWindowController {
    private(set) var window: NSWindow?
    private let preferences: Preferences

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window

        // An LSUIElement app has to ask, and has to ask rudely: the
        // cooperative NSApp.activate() does not activate an agent app at all,
        // so without this the window comes up behind whatever the user was
        // in. Nothing here consults NSApp.isActive, which is never true for
        // this app — the lesson from features 3, 5 and 7.
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pastry Settings"
        window.contentViewController = NSHostingController(
            rootView: PreferencesView(preferences: preferences)
        )
        // Closing it must not destroy it: it is reopened from the menu and
        // from ⌘, and the controller hands back the same window each time.
        window.isReleasedWhenClosed = false
        return window
    }
}
```

- [ ] **Step 5: Run the tests**

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Pastry/PreferencesView.swift Pastry/PreferencesWindowController.swift PastryTests/PreferencesWindowControllerTests.swift
git commit -m "Add the Preferences window and its General tab"
```

---

## Task 4: The two ways in, and the values taking effect

**Files:**
- Modify: `Pastry/StatusMenu.swift`, `Pastry/BezelKeyMap.swift`,
  `Pastry/BezelController.swift`, `Pastry/AppDelegate.swift`
- Test: `PastryTests/StatusMenuTests.swift`, `PastryTests/BezelKeyMapTests.swift`

- [ ] **Step 1: Write the failing tests**

Add to `StatusMenuTests`:

```swift
@Test("offers Preferences with the standard shortcut")
func offersPreferences() {
    let menu = StatusMenu(store: ClipStore()) { _ in }
    let item = menu.menu.items.first { $0.title == "Settings…" }
    #expect(item != nil)
    #expect(item?.keyEquivalent == ",")
    #expect(item?.keyEquivalentModifierMask == .command)
}

/// Lowering it in Preferences has to shorten the menu, not wait for a
/// relaunch.
@Test("shows fewer rows when the display count is lowered")
func honoursALoweredDisplayCount() {
    let store = ClipStore()
    for index in 0..<10 { store.add(Clip.fixture("clip \(index)")) }
    let menu = StatusMenu(store: store, displayCount: 10) { _ in }
    #expect(menu.clipRowCount == 10)

    menu.displayCount = 3
    menu.menuNeedsUpdate(menu.menu)
    #expect(menu.clipRowCount == 3)
}
```

(If `StatusMenuTests` has no `clipRowCount` helper, use whatever the existing
tests count rows with — reuse it, do not add a second way.)

Add to `BezelKeyMapTests`, replacing the `,` row in `otherKeysIgnored`:

```swift
@Test("command-comma opens Preferences")
func commandCommaOpensPreferences() {
    #expect(action(",", keyCode: UInt16(kVK_ANSI_Comma), modifiers: [.command]) == .preferences)
}

/// With the hotkey's modifiers held, the comma key reports "<".
@Test("command-comma still works with the hotkey's modifiers held")
func commandCommaWithModifiersHeld() {
    #expect(
        action("<", keyCode: UInt16(kVK_ANSI_Comma), modifiers: [.command, .shift]) == .preferences
    )
}

/// Without command it is just a comma, and the bezel has no text field.
@Test("a bare comma does nothing")
func bareCommaIgnored() {
    #expect(action(",", keyCode: UInt16(kVK_ANSI_Comma)) == .ignored)
}
```

- [ ] **Step 2: Run them to watch them fail**

Expected: FAIL — no Preferences menu item, `displayCount` is a `let`, and
`.preferences` is not in `BezelAction`.

- [ ] **Step 3: Put `.preferences` back in the key map**

In `Pastry/BezelKeyMap.swift`, add `case preferences` to `BezelAction`, and
match the comma **by key code**, for the same reason the digits are:

```swift
if Int(keyCode) == kVK_ANSI_Comma, modifiers.contains(.command) {
    return .preferences
}
```

Place it with the other key-code matches, before the character fallback.
Delete the spec's note saying ⌘, arrives with feature 8.

- [ ] **Step 4: Give `BezelController` somewhere to send it**

Restore the `openPreferences` closure the feature-7 review removed — now with
a real implementation behind it:

```swift
init(
    store: ClipStore,
    hotKey: HotKeyCombination,
    paste: @escaping (Clip) -> Void,
    openPreferences: @escaping () -> Void
)
```

No default value. A default of `{}` is what let ⌘, silently dismiss the bezel
in feature 7; requiring the argument is what stops that happening again. In
`perform`, `case .preferences: hide(); openPreferences(); return`.

- [ ] **Step 5: Make the menu's display count settable**

In `Pastry/StatusMenu.swift`, change `private let displayCount: Int` to
`var displayCount: Int`, and add the item in `buildFixedItems`, above About:

```swift
addItem("Settings…", action: #selector(preferences), target: self, keyEquivalent: ",")
```

with `var onOpenPreferences: (() -> Void)?` and an `@objc private func
preferences() { onOpenPreferences?() }`.

- [ ] **Step 6: Wire it all up in `AppDelegate`**

```swift
private var preferences: Preferences?
private var preferencesWindow: PreferencesWindowController?
```

In `applicationDidFinishLaunching`, before `restoreHistory()`:

```swift
let preferences = Preferences(loginItem: SystemLoginItem())
preferences.applyDefaultLoginItemOnce()
store.rememberCount = preferences.rememberCount
preferences.onChange = { [weak self] in
    guard let self, let preferences = self.preferences else { return }
    // Lowering Remember discards the oldest clippings at once, which
    // ClipStore already does on set, and that is a deletion — so it has to
    // reach the disk now rather than at the next quiet moment.
    store.rememberCount = preferences.rememberCount
    statusMenu?.displayCount = preferences.displayCount
}
self.preferences = preferences
self.preferencesWindow = PreferencesWindowController(preferences: preferences)
```

Pass `displayCount: preferences.displayCount` to `StatusMenu`, set
`statusMenu.onOpenPreferences`, and pass `openPreferences:` to
`BezelController` — both calling `showPreferences()`:

```swift
private func showPreferences() {
    preferencesWindow?.show()
}
```

- [ ] **Step 7: Run the full suite**

Run: `xcodebuild -project Pastry.xcodeproj -scheme Pastry -destination 'platform=macOS' test`
Expected: PASS, including the 143 already there.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Open Preferences from the menu and from command-comma"
```

---

## Task 5: Check it against the running app

**Files:** none — this is verification.

The window, the activation and `SMAppService` are the three things no unit
test here can prove. Features 5 and 7 both shipped a bug that only real input
found, so this task is not optional.

- [ ] **Step 1: Build and run the app**

- [ ] **Step 2: Check the window comes up in front**

Open it from the status menu while another application is frontmost. It must
appear in front and take keyboard focus. If it comes up behind, the activation
is wrong — see "The three things that will fight back".

- [ ] **Step 3: Check ⌘, from the bezel**

Summon the bezel, press ⌘,. The bezel dismisses and the window appears.

- [ ] **Step 4: Check the counts take effect without a relaunch**

Lower Display to 3, open the status menu: three rows. Lower Remember below the
number of clips held: the oldest go at once, and the history file on disk
shrinks to match within a couple of seconds.

- [ ] **Step 5: Check launch at login**

System Settings › General › Login Items shows Pastry after first launch.
Turning the toggle off removes it; relaunching Pastry leaves it off.

- [ ] **Step 6: Record anything that differed**

Update the design spec with whatever reality turned out to be, as every
feature so far has had to.

---

## Task 6: Update the design spec

**Files:**
- Modify: `docs/superpowers/specs/2026-11-11-pastry-swift-rewrite-design.md`

- [ ] **Step 1: Rewrite §6.4**

Record: Pastry's own window rather than the `Settings` scene, and why; the
1…99 bounds and why; that launch at login is read from `SMAppService` rather
than stored; and that the Hotkeys tab arrives with feature 9.

- [ ] **Step 2: Remove the feature-7 note in §6.3** saying ⌘, arrives with
feature 8, and put the ⌘, row back in the key table.

- [ ] **Step 3: Commit**

```bash
git add docs/
git commit -m "Record what feature 8 settled about Preferences"
```

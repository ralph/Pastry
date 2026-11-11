# Pastry — a Swift/SwiftUI rewrite of Flycut

Date: 2026-11-11
Status: approved, ready for implementation planning

## 1. Context

Flycut is a macOS clipboard-history manager (a fork of Jumpcut), written in
Objective-C, last released in 2019. This project replaces it with **Pastry**: a
much smaller Swift/SwiftUI app that implements only the features actually used,
builds as a notarized Developer ID app, and carries no Objective-C.

The end state is unambiguous: `git ls-files '*.m' '*.h' '*.xib' '*.nib'` returns
nothing, and the only app the repository builds is Pastry.

## 2. Decision: rewrite from scratch

Rejected: incremental file-by-file conversion.

The Objective-C tree is roughly 100k of source, and the large majority of it
implements functionality being dropped — the iOS app and its UI, iCloud/CloudKit
settings and clipping sync, the favorites and "stashed" stores, bezel appearance
configuration, password-detection heuristics, "save forgotten items to disk",
and six vendored libraries (ShortcutRecorder, SGHotKeysLib, UKPrefsPanel,
InAppSettingsKit, MGSwipeTableCell, MJCloudKitUserDefaultsSync) plus a
login-item helper app with its own AppleEvent C code.

What remains in use is small: an ordered clipping store, a pasteboard poller, a
status menu, a bezel window, a global hotkey, and two preferences. That is on
the order of 1,500 lines of Swift.

Incremental conversion would additionally require maintaining a bridging header
and keeping the nib-driven UI alive throughout the transition — carrying the
dead weight *and* writing the replacement. Rewriting is strictly less work.

The Objective-C sources remain on disk as a behavioural reference until the
final step deletes them; they also remain in git history permanently.

## 3. Scope

### Kept

- Clipboard history captured by polling, newest first.
- Menu-bar status item (fixed black scissors icon) listing recent clippings.
- Selecting a menu item pastes it into the frontmost app.
- Search field inside the status menu.
- "Clear All" and "Merge All".
- Global hotkey summoning a bezel overlay; cycling clippings by repeating the
  hotkey's key while modifiers are held; releasing the modifiers pastes.
- Full bezel keyboard and mouse navigation (see §6.3).
- Duplicate removal, and moving a pasted clipping to the top of the list.
- History persisted across launches.
- Preferences: remember count, menu display count, launch at login, hotkey.
- Notarized Developer ID build published as a DMG by GitHub Actions.

### Dropped

- The entire iOS app, its targets, tests and storyboards.
- iCloud / CloudKit sync of settings and clippings.
- The favorites store, the stashed store, and every key bound to them.
- App Store / sandboxed distribution channel and its entitlements.
- The login-item *helper app* (replaced by `SMAppService`).
- Configurable bezel appearance (transparency, width, height) and menu icon.
- Sticky bezel and wraparound bezel options.
- "Save forgotten items to Desktop", and save-to-file from the bezel.
- Password-field heuristics (pasteboard-type lists, length/character guessing)
  and the "reveal pasteboard types" debugging aid.
- The "store disabled" toggle.
- All six vendored third-party libraries. Pastry has **zero** dependencies.

### Behaviour fixed, not configurable

Taken from the reference screenshots of the current installation:

| Behaviour | Value |
| --- | --- |
| Menu selection pastes | on |
| Remove duplicates | on |
| Move pasted item to top of stack | on |
| Sticky bezel | off (releasing the modifiers pastes) |
| Wraparound bezel | off (list clamps at both ends) |
| Bezel shows source app, icon and timestamp | on |
| Menu bar icon | black scissors |

### Icons

The menu-bar glyph is the **SF Symbol `scissors`** rendered as a template
image, so it tracks the menu bar's appearance, light/dark mode and
accessibility sizes automatically and ships no bitmap assets. Flycut's
`com.generalarcade.flycut.black.*.png` files are not carried over.

The app *bundle* icon is produced in step 10 as an `.icns` derived from the same
glyph. For an agent app it is only visible in Finder, the About panel and
System Settings, so it is not needed earlier.
| Save forgotten items anywhere | off |

## 4. Target and distribution

- **Minimum macOS: 26.0.** Nothing in macOS 27 benefits this app, and 26 costs
  nothing to support.
- Swift 6, Xcode 27.
- `LSUIElement` agent app: no Dock icon, no main window, no menu bar menus.
- Not sandboxed. Hardened runtime, Developer ID signed and notarized.
- Bundle identifier: `de.rvdh.Pastry`. Team ID `89S4HZY343`.
- Accessibility permission is required to synthesize the paste keystroke.

## 5. Architecture

Six units, each with one job. Everything below `StatusMenu`/`BezelController`
is free of UI framework dependencies and directly testable.

### 5.1 `Clip`

Value type: `text`, `appName`, `appBundleURL`, `date`. `Codable`. Derives a
truncated single-line `displayText` (40 characters) for the menu; the bezel
shows the full text.

### 5.2 `ClipStore`

The model. Owns an ordered array of `Clip`, newest first, and the current
*stack position* used by the bezel.

- `add(_:)` — inserts at index 0. If an identical-text clip already exists it is
  removed first, so the clip moves to the top rather than duplicating. Trims to
  `rememberNum`.
- `clip(at:)`, `count`, `clear()`, `remove(at:)`.
- `merge()` — joins every clipping oldest-first with newline separators and adds
  the result as a new clipping at the top.
- `search(_:limit:)` — case-insensitive substring filter returning clips with
  their original indices, so menu rows map back to real positions.
- Stack-position movement: `moveOlder()`, `moveNewer()`, `moveOlderByTen()`,
  `moveNewerByTen()`, `moveToFirst()`, `moveToLast()`, `setPosition(_:)`, all
  clamping at the ends (no wraparound), plus `clampPosition()` for use after the
  list shrinks underneath the bezel.

Replaces `FlycutStore` + `FlycutOperator`. No delegate protocol, no journals, no
favorites bookkeeping; SwiftUI and the menu observe it directly.

### 5.3 `ClipboardMonitor`

Polls `NSPasteboard.general.changeCount` every 0.5 s from a `Task` loop rather
than an `NSTimer`. Main-actor work drains on the main queue, which keeps running
while a menu is tracking, so a clipping that arrives with the status menu open is
still seen — the case `.common` run-loop modes existed to solve for the timer.
The task also ends itself if the monitor is released without `stop()`, which a
nonisolated `deinit` cannot do for a non-Sendable `Timer` under Swift 6.

Skips a change when:
- the pasteboard carries `org.nspasteboard.ConcealedType` (the marker password
  managers set), or
- the change count matches the one Pastry caused by writing a clip itself.

Reads the string on a background queue (a large copy over a slow transport can
block) and hands the result to `ClipStore` on the main actor. Captures the
frontmost `NSRunningApplication` for the source name, icon and bundle URL.

There is no notification API for the system pasteboard; polling is the only
mechanism available.

### 5.4 `Paster`

1. Writes the clip's text to the pasteboard through `ClipboardMonitor.write(_:)`,
   which is a single operation: the write returns the change count it produced
   and the monitor records it, so the clip cannot be captured back. This is
   deliberately **not** "write, then suppress" as two calls — that contract can
   be forgotten, and a copy the user makes between the two steps is swallowed.
2. Dismisses whatever UI is showing and yields focus back to the previously
   frontmost app.
3. After a short delay, synthesizes ⌘V with `CGEventPost`, using the **key code**
   for V rather than a character, so non-QWERTY layouts paste correctly. The
   command flag is posted as `maskCommand | 0x8`; the extra bit identifies the
   left command key, which some applications require.

Checks `AXIsProcessTrusted()` and, when untrusted, prompts once via
`AXIsProcessTrustedWithOptions`. The clip is still written to the pasteboard in
that case, so ⌘V by hand works — a clipboard manager that silently does nothing
is worse than one that copies but cannot paste.

**Known limitation: non-QWERTY key positions.** The keystroke is posted by key
code, which is a physical key position rather than the letter V. QWERTY, QWERTZ
and AZERTY all carry V at that position, and Apple's "Dvorak — QWERTY ⌘" layout
reverts to QWERTY positions while Command is held, so those paste correctly.
Plain Dvorak and Colemak do not: Pastry posts whatever letter sits at that
position, so the paste triggers a different shortcut. Flycut used to look up the
key producing "V" in the current layout and replaced that with the fixed key
code to fix a layout bug (upstream `f36ca24`), which is why this is where the
code sits. A proper fix is a `UCKeyTranslate` reverse lookup with the fixed key
code as the fallback; it is not implemented because no Pastry user is affected.

### 5.5 `StatusMenu` (AppKit)

`NSStatusItem` plus `NSMenu`, built with AppKit rather than SwiftUI's
`MenuBarExtra`. A search field inside a menu requires a custom-view
`NSMenuItem`, which `MenuBarExtra(.menu)` cannot express; AppKit also provides
menu keyboard navigation, type-select and dismissal for free.

Contents, top to bottom: up to the display count in clipping rows (newest
first), the search field, a separator, Clear All, Merge All, a separator,
Settings… (⌘,), About Pastry, Quit. Named **Settings…**, not Preferences…,
which is what macOS has called it since Ventura. Typing in the search field re-filters the rows live;
↑/↓ from the field move into the rows.

Rebuilds its rows from scratch in `menuNeedsUpdate(_:)`, which AppKit calls
before the menu is laid out. Flycut instead reused items, because it rebuilt
asynchronously while the menu could already be tracking *and* left
`setMenuChangedMessagesEnabled:NO` in force, so an equal-count swap left the
drawn menu stale. Neither condition applies here.

**The search field's focus dance.** A status menu tracks without activating an
`LSUIElement` application, so nothing in it can become first responder and the
field never sees a keystroke. The menu is therefore cancelled, Pastry activated,
and the menu reopened — Flycut's approach. Three things about it are not
negotiable, each learned by running it:

- `NSApp.activate(ignoringOtherApps: true)`, not the cooperative
  `NSApp.activate()`, which does not activate an agent app at all.
- `NSApp.isActive` is **never** true for this app, even a second after
  activating. Using it to decide anything either spins — cancel, activate,
  never look active, cancel again, at 50% CPU — or abandons the reopen and
  leaves the click dead. A one-shot latch distinguishes the two openings.
- The field's `target`/`action` never fires while a menu tracks; changes
  arrive through `controlTextDidChange`. And rebuilding the whole menu removes
  the row holding the field, which ends its field editor and drops focus after
  one keystroke, so only the clip rows are refreshed.

Arrow keys leave the field by handing the first responder back, which is enough
for the press itself to reach the menu. Flycut also re-posted a synthetic arrow;
on macOS 27 that closes the menu instead.

Each row carries its `Clip` in `representedObject` rather than its index.
Capture continues while the menu is open, so a clip arriving then shifts every
position, and an index-carrying row would act on a different clip than the one
whose title the user read.

Attaching the menu to the status item is a plain `statusItem.menu` assignment.
The search field in feature 5 complicates that: making the field first
responder requires activating the app, which closes the menu the click just
opened, so the menu has to be reopened afterwards. Flycut did that by replaying
the original mouse event, which **stopped working on macOS 27** (upstream
commit `8a24014`). The working approach, and the one to implement, is
`statusItem.popUpStatusItemMenu(_:)` after activation.

### 5.6 `BezelController` + `BezelWindow`

SwiftUI content hosted in an `NSPanel` configured `.nonactivatingPanel` and
`.borderless`, with `canBecomeKey` overridden to `true`.

That combination is load-bearing: the panel accepts key events **without
activating Pastry**, so the application the user was typing in stays frontmost
and the synthesized ⌘V is delivered there. Activating the app instead would
send the paste to the wrong place.

The panel joins all Spaces, centres on the active screen, and is driven by local
`keyDown` and `flagsChanged` monitors. Layout mirrors the current bezel: source
app icon and name with the clipping's timestamp as a header, the clipping text
filling the body, and a "`position` of `count`" pill at the bottom.

### 5.7 `HotKey`

Thin Swift wrapper over Carbon `RegisterEventHotKey`. Carbon is chosen over an
`NSEvent` global monitor because it does not require Accessibility permission to
register, and it reliably receives the key before other applications. Replaces
SGHotKeysLib.

### 5.8 `KeyRecorderView` (SwiftUI)

Small control for the Hotkeys preference: focus it, press a combination, it
captures key code plus modifiers and rejects combinations with no modifier.
Roughly 150 lines, replacing the vendored ShortcutRecorder library.

## 6. Behaviour

### 6.1 Capture

A new pasteboard string becomes a clipping with the frontmost app's localized
name, bundle URL and the current timestamp. Identical text moves an existing
clipping to the top instead of creating a second entry. The list is trimmed to
`rememberNum` (default 40).

### 6.2 Status menu

Shows the newest `displayNum` (default 30) clippings. Selecting one writes it to
the pasteboard, moves it to the top of the list, dismisses the menu and pastes
it into the frontmost app.

### 6.3 Bezel

Summoned by the hotkey (default ⇧⌘V). Pressing the hotkey again while the bezel
is open advances to the next older clipping, which is what makes
"hold ⌘⇧, tap V repeatedly" work.

| Input | Action |
| --- | --- |
| hotkey key again, or ↓ / → / `j` | older clipping |
| ↑ / ← / `k` | newer clipping |
| `1`–`9`, `0` | jump to position 1–10 |
| Home / End | newest / oldest |
| Page Up / Page Down | ±10 |
| Return | paste the shown clipping |
| Delete / Backspace | remove the shown clipping, stay open |
| Escape | dismiss without pasting |
| ⌘, | open Settings |
| clicking away | dismiss without pasting |
| **release the hotkey's modifiers** | paste the shown clipping |

Modifier release pasting is the primary interaction, and follows from sticky
bezel being off.

Two rows of Flycut's table are deliberately absent, found while building
feature 7:

- **⇧ + hotkey key for a newer clipping.** Unreachable for any combination
  that contains shift, which the default ⇧⌘V does — and feature 9 lets the
  user choose another that also might. Carbon claims the whole registered
  combination and calls the hotkey handler rather than delivering the key to
  the bezel, so a tap with ⇧⌘ held can only ever mean "older"; the tap that
  does reach the bezel is the one made after letting go of part of the
  combination. ↑, ← and `k` are how the user walks the other way.
- **Scroll wheel and double-click.** Not implemented; the bezel is a keyboard
  interaction held open by the modifiers, and reaching for the mouse means
  letting go of them, which pastes. Dropped rather than deferred.

The letter and digit keys are matched by **key code, not by the character the
event carries**. The bezel is used with the hotkey's modifiers held down, and
`charactersIgnoringModifiers` still applies Shift: while the user holds ⌘⇧ the
`1` key reports `!` and `j` reports `J`. This is the same physical-position
dependence already recorded for the paste keystroke in §7, and for the same
unavoidable reason.

When the list is empty the bezel shows an "Empty" state and pastes nothing.

### 6.4 Settings

Pastry's own `NSWindow`, hosting a SwiftUI `TabView`. Reached from **Settings…**
in the status menu and from ⌘, in the bezel, both with the standard shortcut.

Not SwiftUI's `Settings` scene, decided in feature 8. The only way to summon
that scene from AppKit is
`NSApp.sendAction(Selector(("showSettingsWindow:")), …)` — a selector that is
not API and has already been renamed once, so it would break for a user rather
than for a test. Feature 9's key recorder also needs the window's responder
chain, which the scene does not hand out. The app keeps an empty `Settings`
scene only because `App` requires one.

Showing the window needs `NSApp.activate(ignoringOtherApps: true)`: the
cooperative `NSApp.activate()` does not activate an agent app at all, and with
no Dock icon a window that came up behind would be unreachable. The same
lesson as features 3, 5 and 7, and for the same reason nothing here may
consult `NSApp.isActive`.

**General** — Remember (default 40), Display in menu (default 30), Launch at
login (default **on**). Lowering Remember below the current count discards the
oldest clippings immediately, and because that is a deletion the history file
is rewritten at once rather than at the next quiet moment.

Both counts are bounded to **1…99**, decided in feature 8: the spec gave
defaults but no limits, zero for Remember is a way to lose work rather than a
setting, and 99 is Flycut's own ceiling. They are clamped when read as well as
when written, since they are ordinary `UserDefaults` keys that anything can
have written. The two stay independent of each other — a Display count above
the Remember count simply shows what exists.

Launch at login is `SMAppService.mainApp`, and its state is **read from the
system every time rather than stored**: the user can turn Pastry off in System
Settings, and a cached boolean would show a toggle that disagrees with what
happens at login. `UserDefaults` holds only a marker saying the default has
been applied once, so a user who turns it off does not find it back on at the
next launch. A registration still awaiting approval is reported in the window,
with a button to System Settings, because macOS answers `register()` that way
rather than with an error.

**Hotkeys** — one key recorder for the bezel hotkey, default ⇧⌘V (key code 9
with command and shift).

A combination must carry at least one of ⌘, ⌃ and ⌥, decided in feature 9.
Shift may join them but never stands alone: ⇧V is a capital V, so such a
hotkey would fire whenever the user typed that letter, in any application,
and they could never type it again. The recorder says so rather than storing
it. Caps lock, fn and the numeric-pad flag are filtered out of what is
stored — they ride along on ordinary events and would make a combination
Carbon could never match again. Escape cancels the recording rather than
being recorded, since it is also the bezel's dismiss key.

**macOS does not report hotkey conflicts.** Verified while another
application held ⇧⌘V: `RegisterEventHotKey` succeeds for the same
combination both with options `0` and with `kEventHotKeyExclusive`, and both
applications then receive the key — which is exactly what happened when
Pastry and Flycut ran together during feature 7, two bezels appearing at
once. So Pastry cannot tell the user that a combination is taken, and does
not claim to: a failed registration means only that registration failed. The
refusal path below is for that, not for conflict detection.

The new combination is **registered before the old one is released**. Carbon
is the only thing that knows whether another application already owns a
combination, and `RegisterEventHotKey` refusing is how that is discovered;
releasing the old one first would leave Pastry with no hotkey at all after a
refusal. Two different combinations never collide, so both are live for the
instant in between. A refused combination **reverts** to the one that works
and the tab says it is taken, rather than storing a hotkey that does nothing.

The combination is shown as a Mac shortcut always is — ⌃⌥⇧⌘ then the key —
and the key is named by asking the **current keyboard layout** through
`UCKeyTranslate`, not from a fixed table. A key code is a physical position
(§7), so a table would name the key wrongly for anyone not on ANSI. Keys with
no character of their own — arrows, function keys, Space, Return — come from
a small table instead.

Changing it takes effect at once: `BezelController.hotKey` is settable, and
the release check and the key map both read it afresh.

## 7. Persistence

History is stored as JSON at
`~/Library/Application Support/Pastry/history.json`, not in `UserDefaults` as
Flycut did.

Written **2 seconds after the last change** (debounced) and again on
`applicationWillTerminate`. Flycut's "save on exit" alone loses everything since
launch on a crash, force-quit or power loss; the debounce removes that failure
mode at the cost of a few-kilobyte write every couple of seconds while actively
copying.

Loaded at launch; a missing, unreadable or malformed file yields an empty
history rather than a crash. Preferences live in `UserDefaults` under the
`de.rvdh.Pastry` domain.

Flycut's existing clippings are **not** migrated. The old store lives in a
sandboxed container under a different bundle identifier, and importing it is not
worth the code.

## 8. Privacy

Clippings marked `org.nspasteboard.ConcealedType` are never recorded. This is
unconditional and has no preference; it only honours an explicit marker set by
the source application, so it is invisible during normal use while keeping
password-manager contents out of both memory and `history.json`.

No heuristic detection by length or character class — that was guesswork with
false positives, and it is gone.

## 9. Repository and project layout

A **fresh standalone repository**, `ralph/Pastry`, **private** for now, not a
GitHub fork. It can be flipped to public at any time; the MIT license and
Flycut attribution are in place from the start so that needs no further work.
The current `ralph/Flycut` fork targets `TermiT/Flycut` upstream, which makes
pull requests default to the wrong repository and ties an app that shares no
code with its ancestor.

The existing working copy is reused in place: `origin` is repointed at the new
repository and `upstream` removed. Full git history is pushed, so Flycut's
history — and the commit that finally deletes it — stays meaningful. The
directory may be renamed to `Pastry` at any later point.

Flycut is MIT licensed. The licence is retained — as `LICENSE`, so GitHub
shows it — carrying General Arcade's notice alongside Pastry's own, and the
README credits Flycut and Jumpcut as the lineage. Every line of Swift is new,
but Pastry reimplements their design and lives in a fork of Flycut's
repository, so removing the notice was not a call the rewrite was entitled to
make.

Project structure, as it ended up:

```
Pastry.xcodeproj
Pastry/              synchronized folder group — app sources, and Pastry.icon
PastryTests/         synchronized folder group — unit tests
tools/icon/          generates Pastry/Pastry.icon from parametric geometry
docs/superpowers/    the spec and one plan per feature
.github/workflows/   ci.yml and release.yml
README.md  CHANGELOG.md  RELEASE_SETUP.md  LICENSE
```

`tools/icon/` is outside `Pastry/` because it builds an input to the app
rather than being part of it; `Pastry.icon` itself has to sit inside the
synchronized folder for actool to compile it (§6.5).

A plain committed `.xcodeproj` using Xcode's **synchronized folder groups**:
files added to the folder join the target automatically, so adding a Swift file
never requires editing `project.pbxproj` by hand. This removes the usual reason
to adopt XcodeGen or Tuist while adding no tooling to CI.

## 10. Build, signing and release

Written fresh rather than adapted: the repository held a `RELEASE_SETUP.md`
describing a `release.yml` that did not exist, so there was nothing to adapt.

`.github/workflows/release.yml` runs on a `v*` tag. It takes the version from
the tag — so the tag and the bundle cannot disagree — builds Release, signs
with Developer ID, submits the DMG to `notarytool`, staples it, and opens a
**draft** GitHub release with the DMG attached. Draft so the artifact is
looked at before anyone else can reach it.

It needs no entitlements file: there is no sandbox, no iCloud and no helper
app, and the hardened runtime is a build setting. Nothing is embedded, so
there is no inside-out signing to do.

**Missing secrets are not a failure.** Without a certificate it builds
unsigned, warns, and still produces a DMG, so the workflow can be exercised
before any of the signing setup exists.

The DMG is built with `diskutil image create`, falling back to `hdiutil
create`: the latter is deprecated as of macOS 26, but the replacement is new
enough that a runner image might not carry it. Both were verified to produce
an image that mounts with the app and an Applications symlink.

Six repository secrets, with Ralph's own team: `CERTIFICATES_P12`,
`CERTIFICATES_PASSWORD`, `NOTARY_TEAM_ID` (`89S4HZY343`), `NOTARY_KEY`,
`NOTARY_KEY_ID`, `NOTARY_ISSUER_ID`. `RELEASE_SETUP.md` covers them, and
drops the Mac App Store channel entirely.

## 11. Testing

Swift Testing (Xcode 27's default) for everything that does not need a running
app:

- `ClipStore`: insertion order, deduplication moving a clip to the top, trimming
  to the remember count, merge output ordering, search index mapping, every
  stack-movement method clamping at both ends, position clamping after the list
  shrinks.
- `Clip`: display-text truncation, newline flattening, `Codable` round-trip.
- Persistence: round-trip through the JSON file, and graceful handling of a
  missing or corrupt file.

`ClipboardMonitor`, `Paster`, the menu and the bezel are verified by running the
app; they are thin wrappers over system services whose value in unit tests is
poor.

## 12. Implementation sequence

Ten features, each its own pull request, each leaving the app working.

1. **Skeleton** — new Xcode project, agent app, status item using the SF
   Symbol scissors glyph, Quit, CI build. New repository created and pushed.
2. **`ClipStore` + `ClipboardMonitor`** — capture and model, with unit tests.
   No visible change beyond clippings appearing in the menu.
3. **Status menu** — clipping rows, Clear All, Merge All, About.
4. **`Paster`** — pasteboard write, focus restore, synthetic ⌘V, Accessibility
   permission flow. Menu selection pastes.
5. **Menu search field.**
6. **Persistence** — JSON store, load at launch, debounced and on-exit saves.
7. **Hotkey + bezel** — Carbon hotkey, non-activating panel, full key handling,
   modifier-release paste.
8. **Preferences: General** — remember/display counts, launch at login.
9. **Preferences: Hotkeys** — key recorder, configurable hotkey.
10. **Release and cleanup** — app icon, release workflow, README, CHANGELOG,
    `RELEASE_SETUP.md`, **and deletion of every Objective-C source, vendored
    library, iOS target and nib**.

Deletion is last so the reference implementation stays readable while the
replacement is built.

**All ten are done.** The repository holds nothing but Pastry: 381 files and
just over 40,000 lines of Objective-C, vendored libraries, nibs and the iOS
target were removed in one commit, with the 198 tests passing either side of
it as the check that nothing deleted was still reachable.

## 13. Risks

- **Non-activating panel focus.** The bezel must take keys without activating
  the app. Getting the panel's style mask, `canBecomeKey` and activation policy
  wrong sends the paste to Pastry instead of the target app. Verify against a
  real editor early in step 7.
- **Accessibility permission.** A fresh bundle identifier means a fresh grant,
  and a stale TCC entry from a rebuilt unsigned binary silently breaks pasting.
  Consistent signing from step 1 avoids most of this; `tccutil reset
  Accessibility de.rvdh.Pastry` is the recovery.
- **Notarization of the first tagged build.** Untestable until the secrets are
  configured. Lower risk than Flycut's, which had nested code to sign; Pastry is
  a single binary.
- **Paste timing.** The delays between hiding the UI, focus returning and
  posting ⌘V are empirical. Flycut uses 0.2 s; keep that unless testing shows
  otherwise.
- **History memory is capped by count, not by size.** Forty clips of
  multi-megabyte pasted text is a few hundred megabytes resident for the life
  of an all-day agent, and nothing evicts it. Matches Flycut, so it is the
  status quo rather than a regression, and no byte budget is implemented. Worth
  revisiting if it bites; a size cap would change observable behaviour and so
  is the user's call, not a silent default.

## 14. Non-goals

Rich-text, image and file clippings (text only, as today); clipboard sync across
machines; sharing a history with iOS; pinned or favorite clippings; snippet
expansion; Mac App Store distribution; migrating Flycut's existing history.

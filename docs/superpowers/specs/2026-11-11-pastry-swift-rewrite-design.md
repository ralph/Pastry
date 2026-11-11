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

Polls `NSPasteboard.general.changeCount` every 0.5 s. The timer is scheduled in
`.common` run-loop mode so polling continues while the status menu is open —
without this, a clipping arriving while the menu is open is missed.

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

1. Writes the clip's text to the general pasteboard and records the resulting
   change count so the monitor ignores it.
2. Dismisses whatever UI is showing and yields focus back to the previously
   frontmost app.
3. After a short delay, synthesizes ⌘V with `CGEventPost`, using the **key code**
   for V rather than a character, so non-QWERTY layouts paste correctly. The
   command flag is posted as `maskCommand | 0x8`; the extra bit identifies the
   left command key, which some applications require.

Checks `AXIsProcessTrusted()` and, when untrusted, prompts once via
`AXIsProcessTrustedWithOptions` and surfaces a clear explanation instead of
silently doing nothing.

### 5.5 `StatusMenu` (AppKit)

`NSStatusItem` plus `NSMenu`, built with AppKit rather than SwiftUI's
`MenuBarExtra`. A search field inside a menu requires a custom-view
`NSMenuItem`, which `MenuBarExtra(.menu)` cannot express; AppKit also provides
menu keyboard navigation, type-select and dismissal for free.

Contents, top to bottom: up to `displayNum` clipping rows (newest first), the
search field, a separator, Clear All, Merge All, Preferences… (⌘,), About
Pastry, a separator, Quit. Typing in the search field re-filters the rows live;
↑/↓ from the field move into the rows.

Rebuilds its rows in place rather than removing and re-adding the whole menu, so
the menu redraws correctly when the row count is unchanged.

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
| ⇧ + hotkey key, or ↑ / ← / `k` | newer clipping |
| `1`–`9`, `0` | jump to position 1–10 |
| Home / End | newest / oldest |
| Page Up / Page Down | ±10 |
| Return | paste the shown clipping |
| Delete / Backspace | remove the shown clipping, stay open |
| Escape | dismiss without pasting |
| ⌘, | open Preferences |
| scroll wheel | cycle clippings |
| double-click | paste |
| **release ⌘ and ⇧** | paste the shown clipping |

Modifier release pasting is the primary interaction, and follows from sticky
bezel being off.

When the list is empty the bezel shows an "Empty" state and pastes nothing.

### 6.4 Preferences

A SwiftUI `Settings` scene with two tabs.

**General** — Remember (default 40), Display in menu (default 30), Launch at
login (default **on**, implemented with `SMAppService.mainApp`). Lowering
Remember below the current count discards the oldest clippings immediately.

**Hotkeys** — one `KeyRecorderView` for the bezel hotkey, default ⇧⌘V
(key code 9 with command+shift).

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

Flycut is MIT licensed. `license.txt` is retained and the README credits Flycut
and Jumpcut as the lineage.

Project structure:

```
Pastry.xcodeproj
Pastry/              synchronized folder group — app sources
PastryTests/         synchronized folder group — unit tests
docs/
.github/workflows/release.yml
```

A plain committed `.xcodeproj` using Xcode's **synchronized folder groups**:
files added to the folder join the target automatically, so adding a Swift file
never requires editing `project.pbxproj` by hand. This removes the usual reason
to adopt XcodeGen or Tuist while adding no tooling to CI.

## 10. Build, signing and release

The existing workflow is adapted rather than replaced — it already imports a
Developer ID certificate, signs inside-out, notarizes with an App Store Connect
API key, staples, builds a DMG and publishes a GitHub Release on a `v*` tag.

It gets simpler: no embedded framework to sign, no helper app inside
`Contents/Library/LoginItems`, and a single entitlements file (hardened runtime,
no sandbox, no iCloud, no `aps-environment`).

Six repository secrets are required, and must be re-created for the new
repository with Ralph's own team: `CERTIFICATES_P12`, `CERTIFICATES_PASSWORD`,
`NOTARY_TEAM_ID` (`89S4HZY343`), `NOTARY_KEY`, `NOTARY_KEY_ID`,
`NOTARY_ISSUER_ID`. `RELEASE_SETUP.md` is rewritten accordingly, dropping the
Mac App Store channel entirely.

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

## 14. Non-goals

Rich-text, image and file clippings (text only, as today); clipboard sync across
machines; sharing a history with iOS; pinned or favorite clippings; snippet
expansion; Mac App Store distribution; migrating Flycut's existing history.

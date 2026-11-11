# Pastry

A clipboard manager that lives in the macOS menu bar. It remembers what you
copy, and gives it back to you with a keystroke.

Pastry is a Swift rewrite of [Flycut](https://github.com/TermiT/Flycut), which
was based on Jumpcut. It keeps the parts that earned their place and drops the
rest.

## What it does

**Remembers what you copy.** Every text clipping goes into a history, newest
first. Clippings an application marks as concealed — password fields, mostly —
are skipped.

**Gives it back two ways.**

Click the scissors in the menu bar for the recent clippings, with a search
field to filter them. Choosing one pastes it where you were typing. The menu
also holds **Clear All**, **Merge All** — which joins the whole history into
one clipping — **Settings…**, **About Pastry**, and **Quit Pastry**, which is
the only way to quit an app with no Dock icon.

Or hold **⇧⌘V** and tap **V** to walk back through the history in a bezel on
screen; let go of the modifiers and the clipping you stopped on is pasted. The
combination is yours to change.

| In the bezel | |
| --- | --- |
| ↓ → `j`, or the hotkey's key again | an older clipping |
| ↑ ← `k` | a newer one |
| `1`–`9`, `0` | jump to the first ten (`0` is the tenth) |
| Home / End | the newest / the oldest |
| Page Up / Page Down | ten at a time |
| Return | paste the clipping shown |
| Delete | remove it, and stay open for the next |
| Escape, or clicking elsewhere | dismiss without pasting |
| ⌘, | open Settings |

The number keys work from the keypad too, as do Enter and forward delete.

**Keeps the history across launches**, in
`~/Library/Application Support/Pastry/history.json`, in a directory only you
can read.

## What it deliberately does not do

The rewrite existed to make the app smaller, so these are absences on purpose,
not gaps waiting to be filled: no iCloud or cross-device sync, no favourites,
no appearance settings, no iOS app. Everything that was a preference in Flycut
but had one sensible answer is now that answer.

## Settings

Under **Settings…** in the menu, or ⌘, in the bezel. Two tabs:

| General | |
| --- | --- |
| Remember | how many clippings to keep — 1 to 99, default 40 |
| Display in menu | how many to show in the menu — 1 to 99, default 30 |
| Launch Pastry at login | on by default; read from the system, so changing it in System Settings wins |

| Hotkeys | |
| --- | --- |
| Summon the bezel | recorded by pressing the combination you want |

Lowering **Remember** discards the oldest clippings straight away.

A hotkey must carry ⌘, ⌃ or ⌥ — ⇧V is a capital V, and such a combination
would fire whenever you typed that letter. The recorder says so rather than
accepting it.

## Permissions

Pasting is done by synthesising ⌘V, which needs **Accessibility** permission.
macOS asks the first time Pastry tries, and sends you to System Settings ›
Privacy & Security › Accessibility. Without it, choosing a clipping still puts
it on the clipboard — you just paste it yourself.

Pastry has no network access, sends nothing anywhere, and keeps no analytics.
The clipboard text never reaches the system log.

## Requirements

macOS 26 or later. No third-party dependencies.

## Building

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry -destination 'platform=macOS' build
```

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry -destination 'platform=macOS' test
```

The Xcode project uses synchronized folder groups, so a new file in `Pastry/`
or `PastryTests/` joins the target on its own — `project.pbxproj` is edited
only for build settings.

## Releasing

Push a `v*` tag. `.github/workflows/release.yml` builds, signs, notarizes and
staples a DMG, and opens a draft release with it attached. See
[RELEASE_SETUP.md](RELEASE_SETUP.md) for the secrets it needs; without them it
still builds, unsigned, so the workflow can be tried first.

## How it is put together

- `Pastry/` — the app. `ClipStore` is the history, `ClipboardMonitor` watches
  the pasteboard, `StatusMenu` is the menu, `BezelController` and friends are
  the bezel, `Paster` sends the keystroke, `HistoryStore` and `DebouncedSaver`
  put it on disk.
- `PastryTests/` — the test suite.
- `docs/` — the design record: the spec, which says what was decided and,
  more usefully, what turned out to be wrong, and one plan per feature.
- `tools/icon/` — the app icon is generated from parametric geometry rather
  than drawn; this builds it.

## Licence

MIT. See [LICENSE](LICENSE), which carries General Arcade's notice as well as
Pastry's own.

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
field to filter them. Choosing one pastes it where you were typing.

Or hold **⇧⌘V** and tap **V** to walk back through the history in a bezel on
screen; let go of the modifiers and the clipping you stopped on is pasted. The
bezel also takes ↑ ↓ ← → and `j`/`k` to move, `1`–`9` and `0` to jump straight
to a position, Home and End for the ends, Page Up and Page Down for ten at a
time, Return to paste, Delete to remove the clipping shown, Escape to dismiss,
and ⌘, to open Settings. The combination is yours to change.

**Keeps the history across launches**, in
`~/Library/Application Support/Pastry/history.json`, in a directory only you
can read.

## What it deliberately does not do

The rewrite existed to make the app smaller, so these are absences on purpose,
not gaps waiting to be filled: no iCloud or cross-device sync, no favourites,
no appearance settings, no iOS app. Everything that was a preference in Flycut
but had one sensible answer is now that answer.

## Settings

Four things, under **Settings…** in the menu or ⌘, in the bezel:

| | |
| --- | --- |
| Remember | how many clippings to keep (default 40) |
| Display in menu | how many to show in the menu (default 30) |
| Launch Pastry at login | on by default; read from the system, so changing it in System Settings wins |
| Summon the bezel | the hotkey, recorded by pressing it |

Lowering **Remember** discards the oldest clippings straight away.

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
- `PastryTests/` — 198 tests.
- `docs/superpowers/specs/` — the design spec, which records what was decided
  and, more usefully, what turned out to be wrong.
- `docs/superpowers/plans/` — one implementation plan per feature.
- `tools/icon/` — the app icon is generated from parametric geometry rather
  than drawn; this builds it.

## Licence

MIT. See [LICENSE](LICENSE), which carries General Arcade's notice as well as
Pastry's own.

# Changelog

Pastry's own history. Flycut's, up to 1.9.7, is in
[that project's repository](https://github.com/TermiT/Flycut).

## Unreleased — 0.1.0

The first Pastry. A Swift rewrite of Flycut, built from nothing and carrying
over no Objective-C.

### What it does

- Remembers what you copy, newest first, skipping clippings an application
  marks as concealed.
- A menu-bar menu with the recent clippings and a search field to filter them.
  Choosing one pastes it where you were typing.
- A bezel on **⇧⌘V**: hold the modifiers and tap the key to walk back through
  the history, let go to paste. Arrows, `j`/`k`, the number keys, Home, End
  and the page keys all move; Return pastes, Delete removes, Escape dismisses.
- The hotkey is yours to change, in Settings › Hotkeys, and takes effect
  without a relaunch.
- Clear All and Merge All, the latter joining the whole history into one
  clipping.
- The history survives a relaunch, kept in a directory only you can read.
  Deleting anything reaches the disk at once rather than at the next quiet
  moment.
- Settings for how many clippings to remember and how many to show, and for
  launching at login.

### What it does not do, on purpose

No iCloud or cross-device sync, no favourites, no appearance settings, no iOS
app. Everything that was a preference in Flycut but had one sensible answer is
now that answer.

### Needs

macOS 26 or later, and Accessibility permission to paste for you. Without that
permission a chosen clipping still goes on the clipboard.

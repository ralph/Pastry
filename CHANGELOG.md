# Changelog

Pastry's own history. Flycut's, up to 1.9.7, is in
[that project's repository](https://github.com/TermiT/Flycut).

## 0.1.1 — 2026-11-12

An icon of its own, and a menu that lines up.

- A new app icon: a cupcake in three-quarter view — paper case, a sliver of
  cake, three turns of piped frosting and a cherry. Drawn for this app rather
  than assembled out of symbols. The menu-bar glyph is unchanged; it is a flat
  monochrome template and always was a separate thing.
- The search field spans the width of the menu instead of stopping short of
  it.

Nothing about what Pastry does has changed.

## 0.1.0 — 2026-11-11

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

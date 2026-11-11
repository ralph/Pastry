# App Store metadata

Everything App Store Connect asks for, written down so it is reviewable here
rather than retyped into a web form. Character limits are Apple's.

**Read `submission-blocker.md` first** — Pastry cannot be submitted as it is
built today.

---

## Identity

| Field | Value |
| --- | --- |
| Name (30) | `Pastry` |
| Subtitle (30) | `Clipboard history, instantly` |
| Bundle ID | `de.rvdh.Pastry` |
| SKU | `pastry` |
| Primary language | English (U.S.) |
| Price | Free |
| Copyright | `2026 Ralph von der Heyden` |
| Age rating | 4+ |

Nothing on the store is called simply "Pastry" — checked across the US and
German storefronts, where every result is "Pastry *something*" (bakery apps
and match-3 games). Uniqueness is only enforced at submission, so this is a
good sign rather than a guarantee.

## Categories

| | |
| --- | --- |
| Primary | **Productivity** |
| Secondary | **Utilities** |

Productivity is where clipboard managers are found and browsed. Utilities as
secondary because a menu-bar tool with no document model fits there too.

## Keywords (100 characters)

```
clipboard,paste,history,copy,snippet,pasteboard,menubar,hotkey,clips,buffer,manager,productivity
```

96 characters. Notes on what is deliberately absent:

- **"Pastry"** — the app name is already indexed; repeating it wastes
  characters.
- **"Flycut", "Jumpcut"** — competitor and predecessor names are a rejection
  risk under App Store Review 2.3.7, even though Pastry descends from them.
- Plurals of words already present: Apple matches them automatically.

## Promotional text (170)

Changeable without a new build, so it is the place for anything time-bound.

```
Pastry remembers everything you copy and gives it back with a keystroke. Hold
⇧⌘V, tap to walk back through your history, let go to paste. No account, no
sync, no telemetry.
```

168 characters.

## Description (4000)

```
Pastry remembers what you copy, so you can paste something from five minutes
ago without going to find it again.

It lives in the menu bar. Nothing else about it is in your way.

GIVE IT BACK TWO WAYS

Hold ⇧⌘V and tap V to walk back through your history in a panel on screen.
Let go of the modifiers and the clipping you stopped on is pasted where you
were typing. It is one gesture, and your hands never leave the keyboard.

Or click the scissors in the menu bar for a list of recent clippings with a
search field to filter them.

BUILT FOR PEOPLE WHO COPY ALL DAY

- Walk the history with the arrow keys, j and k, or the number keys to jump
  straight to a position.
- Search your history as you type.
- Delete a clipping you did not want kept, without leaving the panel.
- Merge the whole history into one clipping.
- Choose your own hotkey. It takes effect immediately.
- Decide how many clippings to keep and how many to show.

QUIET BY DESIGN

Pastry has no network access. It sends nothing anywhere, has no account, no
sync and no analytics. Your clipboard never leaves your Mac, and its contents
never reach the system log.

Clippings that an application marks as concealed — password fields, mostly —
are skipped and never stored.

Your history is kept in a directory only you can read, and survives a
relaunch. Deleting something removes it from disk straight away rather than at
some later moment.

OPEN SOURCE

Pastry is MIT licensed and the whole of it is readable, including the design
decisions and the mistakes made along the way. It is a Swift rewrite of
Flycut, which was based on Jumpcut.

REQUIREMENTS

macOS 26 or later. Pasting into other applications uses macOS Accessibility,
which you grant once when Pastry first asks. Without it, choosing a clipping
still puts it on your clipboard — you just press ⌘V yourself.
```

## URLs

| Field | Value |
| --- | --- |
| Marketing URL | `https://ralph.github.io/Pastry/` |
| Support URL | `https://ralph.github.io/Pastry/support/` |
| Privacy Policy URL | `https://ralph.github.io/Pastry/privacy/` |

A privacy policy URL is **required** even for an app that collects nothing.

## App Privacy

Every answer is "No". Pastry collects nothing, so the privacy nutrition label
is **Data Not Collected** with no categories ticked.

Worth being exact when filling the questionnaire: the clipboard contents
Pastry stores are not "collected" in Apple's sense — collection means
transmitted off the device, and nothing is.

## Review notes

```
Pastry is a clipboard manager. It needs macOS Accessibility permission to
paste into the frontmost application on the user's behalf, which it requests
the first time the user chooses a clipping. Without the permission the app
still works: the chosen clipping goes onto the system clipboard and the user
pastes it themselves.

To test: copy two or three different pieces of text, then hold Shift-Command-V
and tap V to step back through them. Release the modifiers to paste. The
scissors icon in the menu bar shows the same history with a search field.

There is no account, no network access and nothing to sign in to.
```

## What's New (first version)

```
The first release of Pastry.
```

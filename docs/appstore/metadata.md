# App Store metadata

What is on the record in App Store Connect, and why each value is what it is.
Character limits are Apple's.

**Read `submission-blocker.md`** for what still stands between this and a
submission.

| | |
| --- | --- |
| App ID | `6833662343` |
| Bundle ID record | `TVTSP57476` (`de.rvdh.Pastry`, team `89S4HZY343`) |
| State | `PREPARE_FOR_SUBMISSION` |

---

## Identity

| Field | Value |
| --- | --- |
| Name (30) | `Pastry: Clipboard Manager` |
| Subtitle (30) | `Clipboard history, instantly` |
| Bundle ID | `de.rvdh.Pastry` |
| SKU | `pastry` |
| Primary language | English (U.S.) |
| Version | `0.1.0` |
| Release type | Manual |
| Price | Free, all territories, available in new territories |
| Copyright | `2026 Ralph von der Heyden` |
| Age rating | 4+ (every content question declared none/false) |

### The app is not called "Pastry" on the store

It cannot be. App names are unique across **all** App Store Connect accounts,
including names merely *reserved* by developers who never shipped. Three were
refused with `ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE.DIFFERENT_ACCOUNT`:

```
Pastry                    TAKEN
Pastry Clipboard          TAKEN
Pastry Clipboard Manager  TAKEN
Pastry: Clipboard Manager available  ← chosen
```

A public store search for "Pastry" returns only bakery apps and match-3 games,
so these are reservations rather than shipped apps. Note that the public search
cannot tell you this — only an attempted create or rename can.

The app itself is still called Pastry: the bundle name, the site, the DMG and
the repository are unchanged. Only the store listing carries the longer name.

## Categories

| | |
| --- | --- |
| Primary | **Productivity** |
| Secondary | **Utilities** |

Productivity is where clipboard managers are found and browsed. Utilities as
secondary because a menu-bar tool with no document model fits there too.

## Keywords (100 characters)

```
paste,copy,snippet,pasteboard,menubar,hotkey,clips,buffer,productivity,shortcut,keyboard,text
```

93 characters. Notes on what is deliberately absent:

- **`clipboard`, `manager`, `history`** — all three appear in the name or the
  subtitle, and Apple indexes those already. `asc validate` flags the overlap
  as wasted characters, which it is.
- **`Pastry`** — the app name is indexed; repeating it wastes characters.
- **`Flycut`, `Jumpcut`** — competitor and predecessor names are a rejection
  risk under App Store Review 2.3.7, even though Pastry descends from them.
- Plurals of words already present: Apple matches them automatically.

## Promotional text (170)

Changeable without a new build, so it is the place for anything time-bound.

```
Pastry remembers what you copy and gives it back with a keystroke. Hold Shift-Command-V, tap back through your history, let go to paste. No sync, no telemetry.
```

159 characters.

**Apple rejects `⇧` and `⌘` in this field**, with
`An attribute value has invalid characters`. The modifiers have to be spelled
out here. The description field accepts them, which is why it still uses them.

## Description (4000)

1,837 characters. Held as prose with blank lines between paragraphs — the App
Store renders the text verbatim, so it must not carry the hard wrapping this
document uses.

```
Pastry remembers what you copy, so you can paste something from five minutes ago without going to find it again.

It lives in the menu bar. Nothing else about it is in your way.

GIVE IT BACK TWO WAYS

Hold ⇧⌘V and tap V to walk back through your history in a panel on screen. Let go of the modifiers and the clipping you stopped on is pasted where you were typing. It is one gesture, and your hands never leave the keyboard.

Or click the scissors in the menu bar for a list of recent clippings with a search field to filter them.

BUILT FOR PEOPLE WHO COPY ALL DAY

- Walk the history with the arrow keys, j and k, or the number keys to jump straight to a position.
- Search your history as you type.
- Delete a clipping you did not want kept, without leaving the panel.
- Merge the whole history into one clipping.
- Choose your own hotkey. It takes effect immediately.
- Decide how many clippings to keep and how many to show.

QUIET BY DESIGN

Pastry has no network access. It sends nothing anywhere, has no account, no sync and no analytics. Your clipboard never leaves your Mac, and its contents never reach the system log.

Clippings that an application marks as concealed — password fields, mostly — are skipped and never stored.

Your history is kept in a directory only you can read, and survives a relaunch. Deleting something removes it from disk straight away rather than at some later moment.

OPEN SOURCE

Pastry is MIT licensed and the whole of it is readable, including the design decisions and the mistakes made along the way. It is a Swift rewrite of Flycut, which was based on Jumpcut.

REQUIREMENTS

macOS 26 or later. Pasting into other applications uses macOS Accessibility, which you grant once when Pastry first asks. Without it, choosing a clipping still puts it on your clipboard — you just press ⌘V yourself.
```

## URLs

| Field | Value |
| --- | --- |
| Marketing URL | `https://ralph.github.io/Pastry/` |
| Support URL | `https://ralph.github.io/Pastry/support/` |
| Privacy Policy URL | `https://ralph.github.io/Pastry/privacy/` |

All three are set on the record and **none of them resolves yet**: the
repository is private, so GitHub Pages cannot publish. Apple accepted them
without reachability checks at this stage, but a dead privacy policy URL will
fail review.

## App Privacy

Every answer is "No". Pastry collects nothing, so the privacy nutrition label
is **Data Not Collected** with no categories ticked.

This questionnaire is **not** reachable through the API — `asc validate` says
so itself, and it has to be filled and published in the web UI at
[appstoreconnect.apple.com/apps/6833662343/appPrivacy](https://appstoreconnect.apple.com/apps/6833662343/appPrivacy).

Worth being exact when filling it: the clipboard contents Pastry stores are
not "collected" in Apple's sense — collection means transmitted off the
device, and nothing is.

## Review notes

Not yet on the record: creating review details requires a contact first name,
last name, **phone number** and email, and the phone number is not something
this repository should hold. Add it with:

```bash
asc review details-create --version-id 4b36da2c-8b65-4331-92db-22165befc675 \
  --contact-first-name Ralph --contact-last-name "von der Heyden" \
  --contact-email YOU@example.com --contact-phone "+49 ..." \
  --notes "$(cat docs/appstore/review-notes.txt)"
```

The notes themselves:

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

## What's New

Cannot be set yet — Apple returns `Attribute 'whatsNew' cannot be edited at
this time` for a first version with no build attached. It becomes editable
once a build is uploaded. The intended text:

```
The first release of Pastry.
```

## What `asc validate` still reports

Three blocking errors remain, down from thirty:

| Check | What it needs |
| --- | --- |
| `build.required.missing` | a Mac App Store build — see `submission-blocker.md` step 4 |
| `screenshots.required.any` | at least one screenshot set |
| `review_details.missing` | the contact details above |

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
| Marketing URL | `https://pastry.rvdh.de/` |
| Support URL | `https://pastry.rvdh.de/support/` |
| Privacy Policy URL | `https://pastry.rvdh.de/privacy/` |

All three are set on the record and **all three resolve**.
`.github/workflows/site.yml` publishes `site/` to GitHub Pages, served over
HTTPS at `pastry.rvdh.de` — a DNS CNAME to `ralph.github.io`, with the custom
domain set on the repository itself, because an Actions deploy does not read
the artifact's `CNAME` file.

Apple accepted the URLs without reachability checks at this stage. Review will
not: a dead privacy policy URL fails it.

## App Privacy

Every answer is "No". Pastry collects nothing, so the privacy nutrition label
is **Data Not Collected** with no categories ticked.

**Declared and published.** Data usage `dd5e1b3f-e86a-4e74-8401-e0a3619b0c6f`,
one tuple, `DATA_NOT_COLLECTED`, no categories and no purposes.

It is not in the *public* API — which is why `asc validate` still reports
`privacy.publish_state.unverified` and will keep doing so; it cannot read the
publish state, so it tells you to go and look. That note is not a failure. The
web-session API does have it:

```bash
asc web privacy pull --app 6833662343 --pretty      # current state
asc web privacy plan --app 6833662343 --file d.json # diff before touching
asc web privacy apply --app 6833662343 --file d.json
asc web privacy publish --app 6833662343 --confirm
```

with `d.json` being the whole of it:

```json
{ "schemaVersion": 1, "dataUsages": [ { "dataProtections": ["DATA_NOT_COLLECTED"] } ] }
```

Two things worth knowing if this is ever redone. `pull` reports
`DATA_NOT_COLLECTED` before anything has been declared — that is a derived
default, not a saved answer, and only `plan` reveals the difference by showing
the create. And `apply` does not publish: publishing is a separate call, which
is the state review actually checks.

Worth being exact about the answer itself: the clipboard contents Pastry
stores are not "collected" in Apple's sense — collection means transmitted off
the device, and Pastry has no network code at all.

## Screenshots

Four, uploaded to screenshot set `ff679f21-71fa-4cfc-94f2-991fbaad49b6`
(`APP_DESKTOP`), each 2880×1800 — one of the four sizes Apple accepts for Mac.

| Order | Shot | Headline |
| --- | --- | --- |
| 1 | the menu open under the scissors | Everything you copied, one click away. |
| 2 | the bezel mid-walk, 3 of 10 | Hold ⇧⌘V. Tap back. Let go. |
| 3 | the menu filtered by a search | Find it by typing. |
| 4 | Settings, General | Your history, your limits. |

They are real captures of the shipped app, not mock-ups. How they were made,
because it will have to be repeated for 0.2.0:

- **A demo history.** The app reads
  `~/Library/Application Support/Pastry/history.json`, so a hand-written one of
  ten plausible clippings — attributed to Safari, Terminal, Xcode, Notes, Mail
  and Messages — was placed in a throwaway home and Pastry launched with
  `CFFIXED_USER_HOME` pointing at it. Note `HOME` alone does **not** work:
  `FileManager.urls(for: .applicationSupportDirectory, …)` resolves the real
  home regardless. Nothing of the actual user's was touched or shown.
- **A backdrop.** A borderless full-screen window drawing a gradient in the
  site's accent colours (`#FFE9EC` → `#D4687F`), so the translucent menu and
  bezel sample something real. Capturing a window on its own with
  `screencapture -l` renders the vibrancy as flat grey — it must be a
  full-screen capture over a real backdrop, then cropped.
- **A clean menu bar.** The right-hand side of a real menu bar is full of other
  apps' icons. An empty stretch of the same bar was stretched across them and
  the scissors pasted back, which is seamless because the backdrop gradient is
  vertical only.
- **The bezel.** Opened by synthesising ⇧⌘V with the modifiers held down, and
  dismissed with Escape *before* releasing them — releasing would paste into
  whatever was frontmost.
- **Alpha.** `screencapture` output carries an alpha channel and App Store
  Connect rejects it outright, even when every pixel is opaque. Flatten with
  `-alpha remove -alpha off` before uploading.

The two site images in `site/assets/` are tighter crops of the same captures.

## Review notes

On the record: review detail `cf439c93-b18f-4052-81ce-a6439eb1d58a`, with the
contact name, email and phone, and the notes from
`docs/appstore/review-notes.txt` — which is where they live, so the document
and the record cannot drift apart.

**`demoAccountRequired` comes back `true`.** `asc review details-create`
documents the flag as defaulting to false, and the created record said
otherwise. Left alone it tells App Review to expect sign-in credentials for an
app whose own notes say there is nothing to sign in to, and no credentials are
attached. Check it after creating, and turn it off:

```bash
asc review details-update --id REVIEW_DETAIL_ID --demo-account-required=false
```

To recreate this from nothing:

```bash
asc review details-create --version-id 4b36da2c-8b65-4331-92db-22165befc675 \
  --contact-first-name Ralph --contact-last-name "von der Heyden" \
  --contact-email YOUR@email --contact-phone "+49..." \
  --notes "$(cat docs/appstore/review-notes.txt)"
```

The phone has to carry a `+` and a country code, and `details-create` fails on
an existing record — pass `--if-exists update` to change one.

## What's New

Cannot be set yet — Apple returns `Attribute 'whatsNew' cannot be edited at
this time` for a first version with no build attached. It becomes editable
once a build is uploaded. The intended text:

```
The first release of Pastry.
```

## What `asc validate` still reports

One blocking error remains, down from thirty:

| Check | What it needs |
| --- | --- |
| `build.required.missing` | a build *attached to this version* |

A build exists — `12.1`, uploaded on 2026-11-12 from tag `v0.1.1`, processed
to `VALID`. It cannot attach to this record while the record says `0.1.0` and
the build belongs to the `0.1.1` train, so the version string has to move
first. Build numbers come from the workflow as
`GITHUB_RUN_NUMBER.GITHUB_RUN_ATTEMPT`, and Apple will refuse any upload
whose number it has already seen.

Screenshots and App Privacy are done. The `privacy.publish_state.unverified`
line `asc validate` prints alongside these is an info note about the public
API's blind spot, not an outstanding task.

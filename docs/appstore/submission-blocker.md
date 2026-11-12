# What stands between Pastry and the App Store

The metadata is ready. The binary is not, but much less stands in the way than
it looked. This is what was verified, and what is left.

## The Mac App Store requires the App Sandbox

Pastry is built for Developer ID distribution — signed, notarized, stapled,
and handed out as a DMG. That is a different channel with different rules, and
the design spec (§10) deliberately chose it, recording "dropping the Mac App
Store channel entirely".

So this is a decision being reversed rather than an oversight to patch.

## Pasting works under the sandbox — verified twice over

This was the open question, and the one that could have killed the whole idea:
Pastry's core feature is synthesising ⌘V with `CGEvent` (`Keystroke.swift`)
after checking `AXIsProcessTrusted` (`Accessibility.swift`), and it was not
obvious that a sandboxed process would be allowed to.

**By test.** A sandboxed build at
`/tmp/pastry-sb/Build/Products/Release/Pastry.app`, with a fresh Accessibility
grant, pasted into TextEdit on the global hotkey. The control run — the same
gesture with Pastry stopped — left the document empty, ruling out ⇧⌘V being
handled by TextEdit itself.

**By precedent, in this repository's own history.** Flycut ships on the Mac
App Store (`id442160987`), and the code that shipped is in this repo. Its App
Store build was sandboxed (`Flycut.entitlements`,
`com.apple.security.app-sandbox`), and `-fakeCommandV` posts the same
`CGEventPost(kCGHIDEventTap, …)` events Pastry does, with no sandbox guard at
either call site. `FlycutDeveloperID.entitlements` even states the principle
outright: *Accessibility (for synthesizing paste) is governed by TCC, not
entitlements.*

Also confirmed working sandboxed: the global hotkey (`RegisterEventHotKey`
needs no Accessibility and is not sandbox-restricted), the bezel, clipboard
capture, and persistence into the container.

One caveat worth recording, because it cost an hour: a TCC Accessibility grant
is bound to the binary at the granted path. Replacing the app bundle at that
path — swapping in a different build to compare — silently invalidates the
grant while the toggle still appears to be on. Several negative results came
from that rather than from the sandbox, and were wrong.

## Why Pastry's entitlements are shorter than Flycut's

Flycut's App Store entitlements carry four keys Pastry does not need:

| Flycut key | Why Pastry omits it |
| --- | --- |
| `developer.icloud-*`, `aps-environment` | Pastry has no sync. The spec dropped it. |
| `security.files.user-selected.read-write` | Flycut's save-clippings `NSSavePanel`. Pastry has no such feature. |
| `security.automation.apple-events` + System Events exception | Flycut's login-item helper drove System Events. Pastry uses `SMAppService`, which needs no Apple Events. |

`com.apple.security.app-sandbox` alone is the whole file, and the test says
that is sufficient.

## The history moves into a container

`~/Library/Application Support/Pastry/` becomes
`~/Library/Containers/de.rvdh.Pastry/Data/Library/Application Support/Pastry/`.
Nothing migrates on its own, so anyone already running the DMG build would
appear to lose their history, and if both builds ship they are two separate
histories on the same Mac. This needs a decision, not code — either migrate on
first sandboxed launch, or accept the split and say so.

## Review risk

An app whose core function is driving another application's paste command is
the kind of thing App Review takes a view on, and that view cannot be
predicted from here. But Flycut passed review doing exactly this, from this
code, so the risk is a good deal smaller than it first looked.

## What is left to do

1. ~~Add an entitlements file with `com.apple.security.app-sandbox`~~ — done,
   `Pastry/Pastry-AppStore.entitlements`, applied to App Store builds only and
   never to the DMG build.
2. ~~Build sandboxed and test that pasting still works~~ — done, see above.
3. Decide what happens to an existing history.
4. Add a Mac App Store export path to the release workflow: a different signing
   identity (`3rd Party Mac Developer Application`), a provisioning profile,
   and upload through App Store Connect rather than `notarytool`.
5. ~~Create the app record and attach the metadata~~ — done, app `6833662343`,
   with four screenshots. See `metadata.md`.
6. Add the review contact details (a phone number this repository should not
   hold) and fill in the App Privacy questionnaire by hand.

## What is not blocked

Everything else in this folder. The copy, the categories, the keywords, the
screenshots and the website are needed for the direct download too — the DMG
release has no landing page, no support URL and no privacy policy today, and
those are worth having whether or not the app ever reaches the store.

# What stood between Pastry and the App Store

> **Submitted.** 0.1.1, build `12.1`, review submission
> `ffeaf8c8-db9e-419d-8dc5-e170654ed04c`, 2026-11-12. The version is
> `WAITING_FOR_REVIEW`, and the release type is `AFTER_APPROVAL`, so an
> approval puts it on the store with nothing further to press.
>
> The rest of this document is kept as the record of how it got there, in the
> present tense it was written in.

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
4. ~~Add a Mac App Store export path to the release workflow~~ — done, the
   `app-store` job in `.github/workflows/release.yml`. It archives with the
   sandbox entitlements, signs with a distribution identity and an embedded
   provisioning profile, and hands the installer package to App Store Connect.
   The certificates, the profile and the three secrets all exist
   (`RELEASE_SETUP.md` lists them). **It has shipped.** Tag `v0.1.1` ran the
   whole path including the upload —
   [run 43226486857](https://github.com/ralph/Pastry/actions/runs/43226486857)
   — and `Pastry-0.1.1.pkg`, build `12.1`, reached App Store Connect, where
   Apple processed it to `VALID` within a minute.
5. ~~Create the app record and attach the metadata~~ — done, app `6833662343`,
   with four screenshots. See `metadata.md`.
6. ~~Fill in the App Privacy questionnaire~~ — done, declared and published as
   Data Not Collected through `asc web privacy`. See `metadata.md`.
7. ~~Add the review contact details~~ — done, review detail
   `cf439c93-b18f-4052-81ce-a6439eb1d58a`. The phone number is on the record
   and not in this repository, which is where it belongs. See `metadata.md`,
   including the `demoAccountRequired` trap.

Which leaves nothing. `asc validate` reports **no blocking errors**, down from
thirty.

The record was renamed from `0.1.0` to `0.1.1` and build `12.1` is attached to
it. Renaming was the whole of it: a build belongs to the train named by its own
version string, and a record takes builds only from its own train. That is
allowed while the record sits in `PREPARE_FOR_SUBMISSION`.

What did not follow is What's New. The guess that a build would make it
editable was wrong — Apple refuses it for a first release, because there is no
earlier version for anything to be new since. Its warning stays and should.

TestFlight, on the other hand, is running. Beta group **Internal Testers**
(`477bc0f9-1643-4ee7-9ae2-13eb646a8330`) is internal with
`hasAccessToAllBuilds`, so every future upload joins it without anyone
assigning anything, and the account holder is in it. Build `12.1` reads
`internalBuildState: IN_BETA_TESTING`.

Its `externalBuildState` is still `READY_FOR_BETA_SUBMISSION`, and that is the
line between the two kinds of testing: internal testers need no review from
Apple, external ones need a beta review before a build reaches them.

## What is not blocked

Everything else in this folder. The copy, the categories, the keywords, the
screenshots and the website are needed for the direct download too — the DMG
release has no landing page, no support URL and no privacy policy today, and
those are worth having whether or not the app ever reaches the store.

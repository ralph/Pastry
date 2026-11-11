# Pastry cannot be submitted as it is built today

The metadata is ready. The binary is not. This is the gap, and what it would
take to close it.

## The Mac App Store requires the App Sandbox. Pastry has none.

Verified in the project as it stands:

```
sandbox entitlement:  0 occurrences in project.pbxproj
entitlements file:    none
hardened runtime:     enabled (both configurations)
```

Pastry is built for Developer ID distribution — signed, notarized, stapled,
and handed out as a DMG. That is a different channel from the App Store with
different rules, and the design spec (§10) deliberately chose it and recorded
"dropping the Mac App Store channel entirely".

So this is not an oversight to patch. It is a decision being reversed, and the
work is real.

## What enabling the sandbox would change

**The history moves into a container.** `~/Library/Application Support/Pastry/`
becomes
`~/Library/Containers/de.rvdh.Pastry/Data/Library/Application Support/Pastry/`.
Nothing migrates on its own, so anyone already running the DMG build would
appear to lose their history. If both builds ship, they are two separate
histories on the same Mac.

**Pasting needs re-verifying under the sandbox.** Pastry pastes by
synthesising ⌘V with `CGEvent` (`Keystroke.swift`) after checking
`AXIsProcessTrusted` (`Accessibility.swift`). Other clipboard managers do ship
on the Mac App Store and do paste, so this is very likely fine — but "very
likely" is not the standard this project has used for anything else, and it
has to be tested on a sandboxed build before anyone writes a submission.

**The global hotkey should be unaffected.** `RegisterEventHotKey` does not
need Accessibility and is not sandbox-restricted.

**Review risk is the unknown.** An app whose core function is driving another
application's paste command is exactly the kind of thing App Review takes a
view on. That view cannot be predicted from here.

## What would have to happen

1. Add an entitlements file with `com.apple.security.app-sandbox`, and wire
   `CODE_SIGN_ENTITLEMENTS` into the project.
2. Build sandboxed and **test that pasting still works** — the whole feature
   rests on it.
3. Decide what happens to an existing history, or accept that the two builds
   do not share one.
4. Add a Mac App Store export path to the release workflow: a different
   signing identity (`3rd Party Mac Developer Application`), a provisioning
   profile, and `altool`/`notarytool`-free upload through App Store Connect.
5. Only then: create the app record and attach the metadata.

Steps 1 to 4 are a feature's worth of work, with a verification step in the
middle that could still say no.

## What is not blocked

Everything else in this folder. The copy, the categories, the keywords, the
screenshots and the website are all needed for the direct download too — the
DMG release has no landing page, no support URL and no privacy policy today,
and those are worth having whether or not the app ever reaches the store.

# Pastry Feature 10: Release and cleanup — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nothing left in the repository but Pastry, and a tagged push that produces a signed, notarized, stapled DMG on a GitHub release.

**Architecture:** Two halves that do not touch each other. The deletion is mechanical — one `git rm` of everything Objective-C, after rehoming the one thing inside it that must survive. The release workflow is new, triggered by a `v*` tag, and degrades to an unsigned build when the signing secrets are absent so it can be exercised before they exist.

**Tech Stack:** GitHub Actions, `xcodebuild`, `codesign`, `notarytool`, `hdiutil`.

**Spec:** `docs/superpowers/specs/2026-11-11-pastry-swift-rewrite-design.md` §9

## Global Constraints

- macOS 26.0, Swift 6, zero third-party dependencies, bundle id `de.rvdh.Pastry`.
- Repository `ralph/Pastry`, private, base branch `master`.
- Apple Developer Team `89S4HZY343`.
- `project.pbxproj` is edited only for build settings, never for file references.

## The three things that will fight back

**One thing inside the condemned tree must survive.** `Resources/icon/` holds
the generator and the vector sources for the app icon, and `Resources/` is
otherwise entirely legacy. Deleting it wholesale would turn `Pastry/Pastry.icon`
into a binary nobody can regenerate. It moves *before* anything is deleted, and
the scripts are run afterwards to prove they still work.

**`readme.md` → `README.md` is a case-only rename on a case-insensitive
filesystem.** Done as a plain `mv` it can leave the index holding both or
neither. It goes through `git rm` and a fresh `git add`.

**The workflow cannot be fully tested here.** Signing and notarization need
secrets only the repository owner can add, and notarization needs Apple's
service. So the workflow is written to do the whole job when the secrets are
present and to stop cleanly after the build when they are not — which is a
path that *can* be exercised, and Task 6 does exercise it.

## Decisions the spec does not make

- **The MIT licence stays, with attribution.** Every line of Swift is new, but
  Pastry is a reimplementation of Flycut's design living in a fork of Flycut's
  repository, carrying its history. The licence asks that the notice travel
  with copies and substantial portions; keeping it costs nothing and removing
  it would be a claim this plan is not entitled to make. `license.txt` becomes
  `LICENSE`, keeping General Arcade's notice and adding Pastry's, and the
  README says what Pastry is descended from. **Flag this to the user** — it is
  theirs to change, and the only part of this feature that is not reversible
  by editing one file.
- **The icon sources go to `tools/icon/`.** They build an input to the app
  rather than documenting it, so they are tooling, not docs.
- **The artifact is a DMG**, notarized and stapled as one file. `notarytool`
  takes a DMG directly, so there is no zip-for-notarization step and no
  second artifact that could be stapled differently.
- **The version comes from the tag.** `v1.2.3` builds `MARKETING_VERSION=1.2.3`,
  so the tag and the bundle cannot disagree.

## Scope

In: deleting the Objective-C tree and every legacy asset, rehoming the icon
sources, a release workflow, README, CHANGELOG, and the release setup guide.

Out: publishing an actual release — that is the user's to tag once the secrets
are in place. Out: making the repository public.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `.github/workflows/release.yml` | Tag to signed, notarized DMG on a release |
| `README.md` | What Pastry is, what it needs, how to build it |
| `CHANGELOG.md` | Pastry's own history, starting at 0.1.0 |
| `RELEASE_SETUP.md` | The six secrets, and how to cut a release |
| `LICENSE` | MIT, General Arcade and Pastry |
| `tools/icon/` | The icon generator and its sources, moved |

Deleted: 69 `.m` files, 62 `.h` files, `Flycut.xcodeproj`, `English.lproj`,
`Flycut-iOS*`, `FlycutEngine`, `FlycutHelper`, `InAppSettingsKit`, `LoginItem`,
`MGSwipeTableCell`, `MJCloudKitUserDefaultsSync`, `SGHotKeysLib`,
`ShortcutRecorder`, `UI`, `UKPrefsPanel`, `Resources/` (bar the icon sources),
`main.m`, the `.pch` and `.entitlements` files, `Info.plist`,
`configureAppSandboxing.sh`, `flycut.icns`, `help.md`, `help.iOS.md`,
`acknowledgements.txt`, `appStoreReleases.txt`, `award-20*.png`,
`.github/FUNDING.yml`, and the old `readme.md`.

---

## Task 1: Rehome the icon sources

**Files:**
- Move: `Resources/icon/` → `tools/icon/`
- Modify: `tools/icon/build_icon.py`, `tools/icon/preview_icon.py`, `tools/icon/README.md`

- [ ] **Step 1: Move it, before anything is deleted**

```bash
mkdir -p tools
git mv Resources/icon tools/icon
```

- [ ] **Step 2: Repoint both scripts**

Both compute the bundle path from their own location. `HERE.parent.parent` was
the repository root when they lived in `Resources/icon/`, and still is in
`tools/icon/` — so `BUNDLE` needs no change. Verify that rather than assume:

```bash
grep -n "HERE\|REPO\|BUNDLE" tools/icon/*.py
```

If `BUNDLE` resolves to `<repo>/Pastry/Pastry.icon` already, change nothing.

- [ ] **Step 3: Prove they still work**

```bash
python3 tools/icon/build_icon.py
python3 tools/icon/preview_icon.py
git status --short
```

Expected: `build_icon.py` reports `wrote Pastry/Pastry.icon/...`, and
`git status` shows **no modification** to `Pastry/Pastry.icon` — the bundle
regenerates byte for byte, which is what proves the move changed nothing.

- [ ] **Step 4: Update the README inside it**

Replace the "Note on location" section: the generator now lives in `tools/`,
outside anything that gets deleted, and `Resources/` is gone.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Move the icon sources out of the tree feature 10 deletes"
```

---

## Task 2: Delete the Objective-C tree

**Files:** everything listed under "Deleted" above.

- [ ] **Step 1: Delete it**

```bash
git rm -r --quiet \
  AppController.h AppController.m FlycutOperator.h FlycutOperator.m main.m \
  Flycut.xcodeproj English.lproj Flycut-iOS Flycut-iOSTests Flycut-iOSUITests \
  Flycut-iOS-Bridging-Header.h Flycut-iOS_Prefix.pch Flycut_Prefix.pch \
  Flycut.entitlements FlycutDebug.entitlements FlycutDeveloperID.entitlements \
  FlycutEngine FlycutHelper InAppSettingsKit LoginItem MGSwipeTableCell \
  MJCloudKitUserDefaultsSync SGHotKeysLib ShortcutRecorder UI UKPrefsPanel \
  Resources Info.plist configureAppSandboxing.sh flycut.icns \
  acknowledgements.txt appStoreReleases.txt award-2021.png award-2022.png \
  help.md help.iOS.md readme.md .github/FUNDING.yml
```

- [ ] **Step 2: Check nothing Objective-C is left**

```bash
find . -name '*.m' -o -name '*.pch' -not -path './.git/*' | grep -v '\.git' || echo "clean"
git ls-files | awk -F/ '{print $1}' | sort -u
```

Expected remaining: `.github`, `.gitignore`, `CHANGELOG.md`, `LICENSE` (after
Task 3), `Pastry`, `Pastry.xcodeproj`, `PastryTests`, `README.md`,
`RELEASE_SETUP.md`, `docs`, `tools`.

- [ ] **Step 3: Build and test, which is the real check**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry -destination 'platform=macOS' test
```

Expected: PASS, 198 tests. If anything fails, something deleted was reachable
from the Pastry target — put it back rather than working around it.

- [ ] **Step 4: Commit**

```bash
git commit -m "Delete the Objective-C Flycut tree"
```

---

## Task 3: The licence and the README

**Files:**
- Rename: `license.txt` → `LICENSE`
- Create: `README.md`

- [ ] **Step 1: Rename the licence and add Pastry's notice**

```bash
git mv license.txt LICENSE
```

Add above General Arcade's notice, keeping theirs intact:

```
Copyright (C) 2026 Ralph von der Heyden
Copyright (C) 2011 General Arcade, Gennadiy Potapov
```

- [ ] **Step 2: Write `README.md`**

It must say: what Pastry is; that it is a Swift rewrite of Flycut, which was
based on Jumpcut, and carries their MIT licence; what it needs (macOS 26); how
to build and test it; where the design spec and plans live; and what it
deliberately does not have — no iCloud sync, no favourites, no appearance
settings, since those are the simplifications the whole rewrite was for.

Do not describe features that do not exist. Check each claim against the code.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "Add Pastry's README, and keep the licence it inherits"
```

---

## Task 4: CHANGELOG and release setup

**Files:**
- Replace: `CHANGELOG.md`, `RELEASE_SETUP.md`

- [ ] **Step 1: Replace the changelog**

Flycut's history belongs to Flycut. Pastry's starts at `0.1.0`, unreleased,
listing what the rewrite actually delivers: capture with a search field in the
menu, a bezel on a configurable hotkey, persistence, and a Settings window. One
line each, in the user's terms, not the feature numbers.

- [ ] **Step 2: Rewrite `RELEASE_SETUP.md`**

Same shape as the one it replaces, but for Pastry: the six secrets, Team ID
`89S4HZY343` (not Flycut's), how to export the `.p12`, how to make an App
Store Connect API key, and the fact that the workflow builds unsigned when the
secrets are absent so it can be tried first.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "Start Pastry's changelog and its release setup guide"
```

---

## Task 5: The release workflow

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Write it**

```yaml
name: Release

on:
  push:
    tags: ['v*']
  workflow_dispatch:

permissions:
  contents: write

concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false

jobs:
  release:
    runs-on: macos-26
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '26'

      - name: Work out the version
        id: version
        run: |
          set -euo pipefail
          ref="${GITHUB_REF_NAME}"
          case "$ref" in
            v*) version="${ref#v}" ;;
            *)  version="0.0.0" ;;   # workflow_dispatch from a branch
          esac
          echo "version=$version" >> "$GITHUB_OUTPUT"
          echo "Building $version"

      # Absent secrets are not a failure: the build still runs, so the
      # workflow can be exercised before the certificate exists.
      - name: Import the signing certificate
        id: signing
        env:
          CERTIFICATE: ${{ secrets.CERTIFICATES_P12 }}
          CERTIFICATE_PASSWORD: ${{ secrets.CERTIFICATES_PASSWORD }}
        run: |
          set -euo pipefail
          if [ -z "${CERTIFICATE}" ]; then
            echo "signed=false" >> "$GITHUB_OUTPUT"
            echo "::warning::No CERTIFICATES_P12; building unsigned."
            exit 0
          fi
          keychain="$RUNNER_TEMP/build.keychain-db"
          password="$(uuidgen)"
          security create-keychain -p "$password" "$keychain"
          security set-keychain-settings -lut 21600 "$keychain"
          security unlock-keychain -p "$password" "$keychain"
          printf '%s' "$CERTIFICATE" | base64 --decode > "$RUNNER_TEMP/cert.p12"
          security import "$RUNNER_TEMP/cert.p12" -k "$keychain" \
            -P "$CERTIFICATE_PASSWORD" -T /usr/bin/codesign
          rm -f "$RUNNER_TEMP/cert.p12"
          security set-key-partition-list -S apple-tool:,apple:,codesign: \
            -s -k "$password" "$keychain" >/dev/null
          security list-keychains -d user -s "$keychain" \
            $(security list-keychains -d user | tr -d '"')
          echo "signed=true" >> "$GITHUB_OUTPUT"

      - name: Build
        env:
          TEAM_ID: ${{ secrets.NOTARY_TEAM_ID }}
        run: |
          set -euo pipefail
          args=(-project Pastry.xcodeproj -scheme Pastry -configuration Release
                -destination 'generic/platform=macOS'
                -derivedDataPath build
                MARKETING_VERSION='${{ steps.version.outputs.version }}'
                CURRENT_PROJECT_VERSION='${{ github.run_number }}')
          if [ "${{ steps.signing.outputs.signed }}" = "true" ]; then
            args+=(CODE_SIGN_IDENTITY="Developer ID Application"
                   CODE_SIGN_STYLE=Manual
                   DEVELOPMENT_TEAM="$TEAM_ID"
                   OTHER_CODE_SIGN_FLAGS=--timestamp)
          else
            args+=(CODE_SIGNING_ALLOWED=NO)
          fi
          xcodebuild "${args[@]}" build

      - name: Package the DMG
        id: package
        run: |
          set -euo pipefail
          app="build/Build/Products/Release/Pastry.app"
          test -d "$app" || { echo "no app at $app"; exit 1; }
          staging="$RUNNER_TEMP/dmg"
          mkdir -p "$staging"
          cp -R "$app" "$staging/"
          ln -s /Applications "$staging/Applications"
          dmg="Pastry-${{ steps.version.outputs.version }}.dmg"
          hdiutil create -volname "Pastry" -srcfolder "$staging" \
            -ov -format UDZO "$dmg"
          echo "dmg=$dmg" >> "$GITHUB_OUTPUT"

      - name: Notarize and staple
        if: steps.signing.outputs.signed == 'true'
        env:
          KEY: ${{ secrets.NOTARY_KEY }}
          KEY_ID: ${{ secrets.NOTARY_KEY_ID }}
          ISSUER_ID: ${{ secrets.NOTARY_ISSUER_ID }}
        run: |
          set -euo pipefail
          if [ -z "${KEY}" ]; then
            echo "::warning::Signed but no NOTARY_KEY; skipping notarization."
            exit 0
          fi
          printf '%s' "$KEY" | base64 --decode > "$RUNNER_TEMP/key.p8"
          xcrun notarytool submit "${{ steps.package.outputs.dmg }}" \
            --key "$RUNNER_TEMP/key.p8" --key-id "$KEY_ID" \
            --issuer "$ISSUER_ID" --wait --timeout 30m
          rm -f "$RUNNER_TEMP/key.p8"
          xcrun stapler staple "${{ steps.package.outputs.dmg }}"
          xcrun stapler validate "${{ steps.package.outputs.dmg }}"

      - name: Publish the release
        if: startsWith(github.ref, 'refs/tags/v')
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          set -euo pipefail
          notes="Pastry ${{ steps.version.outputs.version }}"
          if [ "${{ steps.signing.outputs.signed }}" != "true" ]; then
            notes="$notes

**Unsigned build** — the signing secrets were not configured when this ran."
          fi
          gh release create "${GITHUB_REF_NAME}" \
            "${{ steps.package.outputs.dmg }}" \
            --title "Pastry ${{ steps.version.outputs.version }}" \
            --notes "$notes" \
            --draft

      - name: Keep the DMG even when nothing was published
        uses: actions/upload-artifact@v4
        with:
          name: Pastry-dmg
          path: ${{ steps.package.outputs.dmg }}
```

The release is created as a **draft** on purpose: the user looks at the DMG
before anyone else can.

- [ ] **Step 2: Check the YAML parses**

```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/release.yml')); print('ok')"
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "Add the release workflow"
```

---

## Task 6: Prove the release path as far as it can be proved here

**Files:** none — this is verification.

- [ ] **Step 1: Build Release locally, unsigned, exactly as the workflow does**

```bash
xcodebuild -project Pastry.xcodeproj -scheme Pastry -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath /tmp/pastry-release \
  MARKETING_VERSION=0.1.0 CODE_SIGNING_ALLOWED=NO build
```

- [ ] **Step 2: Check the built app**

```bash
plutil -p /tmp/pastry-release/Build/Products/Release/Pastry.app/Contents/Info.plist \
  | grep -iE 'CFBundleShortVersionString|CFBundleIdentifier|LSUIElement|IconName'
```

Expected: version `0.1.0`, id `de.rvdh.Pastry`, `LSUIElement` true, an icon name.

- [ ] **Step 3: Make the DMG the same way the workflow does, and mount it**

Proves the packaging step, which is the part most likely to be wrong.

- [ ] **Step 4: Run the Release build once**

A Release build has different optimisation and no test host. Launch it, check
the menu-bar icon appears and the history still works, then quit. Ask before
doing this if the user is at the machine.

- [ ] **Step 5: Record anything that differed**

---

## Task 7: Update the design spec

**Files:**
- Modify: `docs/superpowers/specs/2026-11-11-pastry-swift-rewrite-design.md`

- [ ] **Step 1: Mark the rewrite complete**

The feature list gets its last tick. §9 records what the release actually does:
tag-driven, version from the tag, DMG, notarized and stapled, draft release,
and that it builds unsigned without secrets.

- [ ] **Step 2: Record the licence decision** and that the repository now holds
nothing but Pastry.

- [ ] **Step 3: Commit**

```bash
git add docs/
git commit -m "Record what feature 10 settled"
```

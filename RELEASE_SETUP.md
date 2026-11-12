# Cutting a Pastry release

Releases come from `.github/workflows/release.yml`, which runs when a `v*` tag
is pushed. It runs the tests, builds the app, signs it, packages a DMG,
notarizes and staples **the DMG**, and opens a **draft** GitHub release with it
attached — draft so you see it before anyone else does.

A second job then builds the same version again for the **Mac App Store** —
sandboxed, signed with a distribution certificate, wrapped in an installer
package and uploaded to App Store Connect. It runs after the first one and
cannot affect it. [Shipping to the Mac App Store](#shipping-to-the-mac-app-store)
below covers what it needs; until those secrets exist it warns and does
nothing.

The release notes come from the matching section of `CHANGELOG.md`, so write
that before tagging. A version with no section gets a bare title and a warning
rather than a failure.

The workflow adapts to whichever secrets are present. With none it still
builds and packages, unsigned, so you can watch it work before setting any of
this up. With all six it does the whole job.

## Trying it without tagging

The workflow can be run by hand. It builds, signs and notarizes exactly as a
tag would, but publishes nothing:

```bash
gh workflow run Release --repo ralph/Pastry --ref main -f version=0.1.0
```

The version is only for the dry run — pass one that exists in the changelog to
see the notes it would publish. Leave it out and it builds `0.0.0`. The DMG is
attached to the run as an artifact either way.

## The six secrets

Add these under **Settings → Secrets and variables → Actions** in the
`ralph/Pastry` repository.

| Secret | What it is |
| --- | --- |
| `CERTIFICATES_P12` | base64 of your **Developer ID Application** certificate, exported as `.p12` |
| `CERTIFICATES_PASSWORD` | the password you set when exporting that `.p12` |
| `NOTARY_TEAM_ID` | your Apple Developer Team ID — `89S4HZY343` |
| `NOTARY_KEY` | base64 of your App Store Connect API key (`.p8`) |
| `NOTARY_KEY_ID` | that key's **Key ID** |
| `NOTARY_ISSUER_ID` | that key's **Issuer ID** |

### Exporting the certificate

You need a **Developer ID Application** certificate — not Apple Development,
not Mac App Store. If you have not got one, make it at
[developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates),
then download and double-click it so it lands in your login keychain.

In **Keychain Access**, find it under **My Certificates**, right-click →
**Export…**, choose **Personal Information Exchange (.p12)**, and set a
password. That password is `CERTIFICATES_PASSWORD`.

Then:

```bash
base64 -i Certificates.p12 | pbcopy
```

and paste that as `CERTIFICATES_P12`.

### Making the notarization key

Notarization uses an App Store Connect API key rather than your Apple ID, so
no password or app-specific password is involved.

At [appstoreconnect.apple.com/access/integrations/api](https://appstoreconnect.apple.com/access/integrations/api),
create a key with the **Developer** role. Apple lets you download the `.p8`
**once**. On that page you also see the **Key ID** and, at the top, the
**Issuer ID**.

```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

`NOTARY_KEY` is that, `NOTARY_KEY_ID` is the Key ID, `NOTARY_ISSUER_ID` is the
Issuer ID.

## Shipping to the Mac App Store

The store is a different channel with different rules, so the `app-store` job
builds the app a second time rather than reusing the DMG's build. It is
sandboxed (`Pastry/Pastry-AppStore.entitlements`, applied from the command
line so it can never reach the Developer ID build), signed with a distribution
certificate rather than Developer ID, and delivered as an installer package.

It runs after the DMG job and attaches nothing to the GitHub release, so a
failure there leaves the download everyone actually uses alone. On a tag it
uploads; on a manual run it builds the package and stops, which is how you
exercise the path without putting a build in front of App Store Connect.

Uploading reuses `NOTARY_KEY`, `NOTARY_KEY_ID` and `NOTARY_ISSUER_ID` — the
same App Store Connect API key, which needs no extra role for this. Three more
secrets are needed:

| Secret | What it is |
| --- | --- |
| `APPSTORE_CERTIFICATES_P12` | base64 of a `.p12` holding **both** distribution certificates |
| `APPSTORE_CERTIFICATES_PASSWORD` | the password you set when exporting that `.p12` |
| `APPSTORE_PROVISIONING_PROFILE` | base64 of the Mac App Store provisioning profile |

### What already exists

All three were created on 2026-11-12 and expire on **2027-11-12**. Both
identities are in the login keychain on Ralph's Mac.

| | ID | Common name |
| --- | --- | --- |
| Application certificate | `23R88S829S` | `3rd Party Mac Developer Application: Ralph von der Heyden (89S4HZY343)` |
| Installer certificate | `ATS35AD54Z` | `3rd Party Mac Developer Installer: Ralph von der Heyden (89S4HZY343)` |
| Provisioning profile | `2YLNKMDR3N` | `Pastry App Store`, for `de.rvdh.Pastry` |

The rest of this section is how to make them again when they expire.

### The two certificates

The store wants two, and one `.p12` has to carry both: the **application**
certificate signs the app, the **installer** certificate signs the package
around it. Neither is the Developer ID certificate the DMG uses, and a
Developer ID certificate in this secret fails the job with a message saying so.

Make them at
[developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates),
or from here:

```bash
asc certificates create --certificate-type MAC_APP_DISTRIBUTION --generate-csr --key-out app.key --csr-out app.csr
```

```bash
asc certificates create --certificate-type MAC_INSTALLER_DISTRIBUTION --generate-csr --key-out installer.key --csr-out installer.csr
```

Then pair each certificate with its key (`asc certificates export`), import
both into one throwaway keychain, and export the two together:

```bash
security export -k throwaway.keychain-db -t identities -f pkcs12 -P "$password" -o appstore.p12
```

A keychain holding only these two is what makes that safe — `security export`
takes everything it finds. The Keychain Access route works too: under **My
Certificates**, select both, right-click → **Export 2 items…**, **Personal
Information Exchange (.p12)**.

> **A `.p12` that OpenSSL 3 or later wrote cannot be imported by `security`.**
> It encrypts with PBES2/AES-256 by default, and macOS answers with
> `MAC verification failed during PKCS12 import (wrong password?)` — which
> sends you looking for a wrong password that is in fact correct. Re-encode
> with `openssl pkcs12 -export -legacy` before importing. Anything that comes
> out of Keychain Access or `security export` is already fine.

### The provisioning profile

A Mac App Store profile for `de.rvdh.Pastry`, tied to the application
certificate above. The job embeds it in the app and fails if the exported
build has none.

```bash
asc profiles create --name "Pastry App Store" --profile-type MAC_APP_STORE --bundle TVTSP57476 --certificate 23R88S829S
```

`TVTSP57476` is the bundle ID record for `de.rvdh.Pastry`. Then download it:

```bash
asc profiles download --id PROFILE_ID --output Pastry.provisionprofile
```

### Setting the three secrets

```bash
base64 -i appstore.p12 | gh secret set APPSTORE_CERTIFICATES_P12 --repo ralph/Pastry
```

```bash
gh secret set APPSTORE_CERTIFICATES_PASSWORD --repo ralph/Pastry < p12.password
```

```bash
base64 -i Pastry.provisionprofile | gh secret set APPSTORE_PROVISIONING_PROFILE --repo ralph/Pastry
```

Everything here expires after a year, and the job starts failing when it does.
That is the one part of this that needs renewing.

### After the upload

Uploading is not submitting. The build appears in App Store Connect a few
minutes later, after Apple has processed it; it then has to be attached to the
version and submitted for review by hand. `docs/appstore/metadata.md` has the
state of the listing.

## Cutting a release

The version comes from the tag, so the tag and the bundle cannot disagree:
`v1.2.3` builds `1.2.3`.

```bash
git tag v0.1.0
```

```bash
git push origin v0.1.0
```

**Push the one tag, never `--tags`.** This repository began as a fork of
Flycut and still carries its release tags locally (`1.8`, `1.8.1`, `1.8.2`,
`1.9.3`, `1.9.4`, `1.9.6`). They are not on `origin`, and a `git push --tags`
would publish six Objective-C Flycut releases onto Pastry. To be rid of the
risk entirely:

```bash
git tag -d 1.8 1.8.1 1.8.2 1.9.3 1.9.4 1.9.6
```

Then watch **Actions**. When it finishes, the draft release is under
**Releases** with `Pastry-0.1.0.dmg` attached. Check it, then publish.

## Checking the DMG yourself

Worth doing once, on the first signed release:

```bash
xcrun stapler validate Pastry-0.1.0.dmg
```

```bash
spctl --assess --type open --context context:primary-signature -vv Pastry-0.1.0.dmg
```

The second should say `accepted` and `source=Notarized Developer ID`. The real
test is a machine that has never seen the app: mount the DMG, drag Pastry to
Applications, and open it. No Gatekeeper warning means it is properly
notarized.

## When it goes wrong

**`notarytool` says `Invalid`.** It prints a submission id; ask Apple what it
objected to:

```bash
xcrun notarytool log <submission-id> --key AuthKey.p8 --key-id <id> --issuer <id>
```

Usually a missing hardened runtime or a missing secure timestamp. The
timestamp comes from the workflow (`OTHER_CODE_SIGN_FLAGS=--timestamp`); the
hardened runtime is a project setting (`ENABLE_HARDENED_RUNTIME`), so that one
means the build settings changed. The workflow checks both before submitting,
so in practice it fails in seconds rather than after Apple's round trip.

**The release is built unsigned.** `CERTIFICATES_P12` is missing or empty. The
workflow says so in its summary rather than failing, by design.

**Signing fails with `no identity found`.** The `.p12` does not contain a
Developer ID Application certificate, or it was exported without its private
key — export from **My Certificates**, not **Certificates**.

**`MAC verification failed during PKCS12 import (wrong password?)`.** The
password is almost certainly right. The `.p12` was written by OpenSSL 3 or
later, whose default encryption macOS cannot read. See the warning under
[the two certificates](#the-two-certificates).

**`exportArchive No certificate for team … matching 'Mac Installer
Distribution' found`.** Those words are Xcode's own automatic selectors, and
they match nothing when the certificate is one of the older `3rd Party Mac
Developer` ones. The job reads the real names out of the keychain instead, so
this should not come back — but that is why it does it the long way.

# Cutting a Pastry release

Releases come from `.github/workflows/release.yml`, which runs when a `v*` tag
is pushed. It builds the app, signs it, notarizes and staples it, packages a
DMG, and opens a **draft** GitHub release with the DMG attached — draft so you
see it before anyone else does.

The workflow adapts to whichever secrets are present. With none it still
builds and packages, unsigned, so you can watch it work before setting any of
this up. With all six it does the whole job.

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

## Cutting a release

The version comes from the tag, so the tag and the bundle cannot disagree:
`v1.2.3` builds `1.2.3`.

```bash
git tag v0.1.0
```

```bash
git push origin v0.1.0
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

Usually a missing hardened runtime or a missing secure timestamp. Both are set
by the workflow, so this means the build settings changed.

**The release is built unsigned.** `CERTIFICATES_P12` is missing or empty. The
workflow says so in its summary rather than failing, by design.

**Signing fails with `no identity found`.** The `.p12` does not contain a
Developer ID Application certificate, or it was exported without its private
key — export from **My Certificates**, not **Certificates**.

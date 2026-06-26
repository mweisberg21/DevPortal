# Packaging

DevPortal is distributed as a macOS `.app` bundle built from SwiftPM output.

## Local Package

```bash
./script/build_and_run.sh --package
```

This creates:

```text
dist/DevPortal.app
```

The script:

1. Builds the SwiftPM executable.
2. Stages a macOS app bundle.
3. Copies `Resources/AppIcon.icns`.
4. Copies `Sparkle.framework` into `Contents/Frameworks`.
5. Writes `Info.plist`, including Sparkle's feed URL and public EdDSA key.
6. Ad-hoc signs the framework and app bundle.

Ad-hoc signing is enough for local launch and ServiceManagement development, but
it is not a replacement for Developer ID signing and notarization.

## Release Zip

```bash
DEVPORTAL_VERSION=0.1.0 ./script/build_and_run.sh --zip
```

This creates:

```text
dist/DevPortal.app.zip
```

## GitHub Releases

Tags matching `v*` trigger `.github/workflows/release.yml`.

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow runs tests, builds `DevPortal.app.zip`, generates `appcast.xml`,
and publishes a GitHub Release with changelog-derived notes.

## Sparkle Updates

DevPortal uses Sparkle for app updates. Release builds include:

- `SUFeedURL`: `https://github.com/mweisberg21/DevPortal/releases/latest/download/appcast.xml`
- `SUPublicEDKey`: the public EdDSA key generated for DevPortal
- `Sparkle.framework`: embedded under `Contents/Frameworks`

The private EdDSA key is not committed. It is stored in GitHub Actions as the
`SPARKLE_PRIVATE_KEY` secret and is passed to Sparkle's `generate_appcast` tool
through standard input.

The release workflow uploads both:

```text
DevPortal.app.zip
appcast.xml
```

`appcast.xml` points to the zip asset for the same tag and includes Sparkle's
EdDSA signature.

## Future Signing And Notarization

The current release workflow is intentionally simple and uses ad-hoc signing.
Before a broad public release, add Developer ID signing and notarization with
GitHub Actions secrets:

- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- signing certificate material

Once signing is in place, update this document and the release workflow so users
can install without Gatekeeper warnings.

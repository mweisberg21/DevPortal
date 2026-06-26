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
4. Writes `Info.plist`.
5. Ad-hoc signs the bundle.

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

The workflow runs tests, builds `DevPortal.app.zip`, and publishes a GitHub
Release with changelog-derived notes.

## Future Signing And Notarization

The current release workflow is intentionally simple. Before a broad public
release, add Developer ID signing and notarization with GitHub Actions secrets:

- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- signing certificate material

Once signing is in place, update this document and the release workflow so users
can install without Gatekeeper warnings.

# Contributing To DevPortal

Thanks for helping improve DevPortal.

## TL;DR

- Small fixes and docs improvements can go straight to a pull request.
- Open an issue before substantial product, architecture, or UX changes.
- Run `swift test` before opening a pull request.
- Add a `CHANGELOG.md` entry for user-facing changes.

## Prerequisites

- macOS 14 or newer
- Xcode Command Line Tools

Install the tools with:

```bash
xcode-select --install
```

## Local Development

From the repository root:

```bash
swift test
./script/build_and_run.sh
```

Useful commands:

```bash
swift build
swift test
swift run DevPortal --scan-once
./script/build_and_run.sh --package
./script/build_and_run.sh --verify
```

## Project Shape

DevPortal is intentionally a compact SwiftPM macOS app:

- `Sources/DevPortal/App`: app entry point
- `Sources/DevPortal/Models`: data models
- `Sources/DevPortal/Services`: scanners, process control, notifications, launch-at-login
- `Sources/DevPortal/Stores`: app state and orchestration
- `Sources/DevPortal/Support`: parsers and helpers
- `Sources/DevPortal/Views`: SwiftUI views
- `Tests/DevPortalTests`: unit tests

## Before Opening A Pull Request

- Explain the user-facing behavior change.
- Include screenshots or screen recordings for UI changes when practical.
- Describe manual testing.
- Run `swift test`.
- Add or update tests for parser, classifier, scanner, or model behavior.
- Add a `CHANGELOG.md` entry for user-facing changes.

## Release Notes

Write changelog entries for someone reading release notes, not for someone
reviewing implementation. Prefer:

```text
- Docker new-port notifications now ignore containers without mapped host ports.
```

over:

```text
- Refactored notification ID filtering.
```

## Security

Do not report security vulnerabilities through public issues. See
[SECURITY.md](SECURITY.md).

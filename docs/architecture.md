# Architecture

DevPortal is a SwiftPM macOS menu-bar app built with SwiftUI and AppKit
integration where needed.

## High-Level Flow

```text
MenuBarExtra / Inspector
        |
        v
ServerStore
        |
        v
ServerScanner
   |            |
   v            v
PortScanner   DockerScanner
   |            |
   v            v
LsofParser    DockerPortParser
```

`ServerStore` owns the user-visible app state. It refreshes scanner output,
applies visibility rules, tracks first-seen/runtime data, records history, and
posts notifications.

`DevPortalApp` owns the Sparkle `SPUStandardUpdaterController` and passes the
updater into the menu-bar view for manual update checks.

## Source Layout

- `Sources/DevPortal/App`: app entry point and command-line diagnostic mode
- `Sources/DevPortal/Models`: data models for ports, Docker, preferences, and snapshots
- `Sources/DevPortal/Services`: command execution, scanning, process control, notifications, launch-at-login
- `Sources/DevPortal/Stores`: observable app state and orchestration
- `Sources/DevPortal/Support`: parsers, classification, persistence, formatting, diagnostics
- `Sources/DevPortal/Views`: SwiftUI menu and inspector UI

## Scanning

Port scanning uses macOS command-line tools:

- `lsof` for listening TCP ports and working directories
- `ps` for process command and parent process information
- `docker ps --format '{{json .}}'` for Docker containers when Docker is present

`LocalPortClassifier` separates likely web dev servers from other local ports.
The classifier is intentionally conservative: uncertain listeners are shown as
other local ports instead of being treated as dev servers.

## Process Actions

DevPortal can:

- open a local URL through `NSWorkspace`
- reveal a folder through Finder
- open Terminal in a working directory
- send `SIGINT` to owned web server processes
- send `SIGTERM` when the user confirms termination
- run Docker stop/log commands when Docker is installed

Destructive actions should stay explicit, visible, and reversible where possible.

## Persistence

Preferences, visibility rules, first-seen tracking, and history are stored in
`UserDefaults` as JSON-encoded values. DevPortal does not use a database, account,
or cloud service.

## Updates

Sparkle is linked through SwiftPM and embedded into the manually staged app
bundle under `Contents/Frameworks/Sparkle.framework`. The app reads its update
feed URL and public EdDSA key from `Info.plist`.

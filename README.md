# DevPortal

Find local dev servers, Docker ports, and nearby local listeners from your macOS
menu bar.

DevPortal is a free, open-source macOS utility for people who often leave local
servers running in the background. Open the menu-bar item to see likely web dev
servers, Docker containers, and other local listeners, then open, inspect, copy,
or stop them without hunting through terminal tabs.

[Download](https://github.com/mweisberg21/DevPortal/releases) ·
[Contributing](CONTRIBUTING.md) · [Privacy](docs/privacy.md) ·
[Security](SECURITY.md)

## Features

- Lists likely web development servers from local listening ports.
- Opens detected URLs in your default browser.
- Shows process, command, working folder, git/package hints, and runtime age.
- Groups Docker containers and mapped host ports when Docker is available.
- Opens Docker logs and stops containers or Compose projects.
- Stops owned web servers with `SIGINT`, with termination available when needed.
- Tracks recent server history and first-seen times.
- Supports ignore and always-show visibility rules.
- Sends optional notifications for new dev servers and long-running servers.
- Supports launch-at-login registration through macOS ServiceManagement.

## Install

Download the latest macOS build from
[GitHub Releases](https://github.com/mweisberg21/DevPortal/releases), unzip
`DevPortal.app.zip`, and move `DevPortal.app` to `/Applications`.

Early builds may be unsigned or ad-hoc signed. If macOS blocks the app, open
**System Settings > Privacy & Security** and choose **Open Anyway**, or build from
source.

## Build From Source

Prerequisites:

- macOS 14 or newer
- Xcode Command Line Tools

Install the command line tools with:

```bash
xcode-select --install
```

Then from the repository root:

```bash
swift test
./script/build_and_run.sh --package
open dist/DevPortal.app
```

For a normal local development run:

```bash
./script/build_and_run.sh
```

The script builds a SwiftPM executable, stages `dist/DevPortal.app`, and launches
it as a menu-bar-only app.

## Common Commands

```bash
swift script/make_app_icon.swift      # regenerate Resources/AppIcon.icns
swift test                            # run unit tests
swift run DevPortal --scan-once       # print a one-time scanner diagnostic
./script/build_and_run.sh             # build and run the menu-bar app
./script/build_and_run.sh --package   # stage dist/DevPortal.app
./script/build_and_run.sh --zip       # stage dist/DevPortal.app.zip
./script/build_and_run.sh --verify    # build, launch, and check the process
```

## What It Shows

- **Web Dev Servers**: likely dev servers, based on process names, commands, and
  common dev ports.
- **Docker**: running containers with mapped host ports, when Docker is
  available. Compose labels are grouped and exposed when Docker provides them.
- **Other Local Ports**: local listeners that may be useful to inspect but are
  not treated as likely dev servers.

Each local server row includes actions to open the URL, copy details, reveal the
working folder, open Terminal in that folder, stop gracefully with `SIGINT`, or
terminate with `SIGTERM`.

Stopping items in **Other Local Ports** asks for confirmation. Termination always
asks for confirmation.

## Inspector

Open **Open Inspector** from the menu bar item for a searchable window with:

- server, Docker, and local-port details
- runtime age and first-seen tracking
- package/git/source hints
- batch **Stop All Web**
- recent history
- ignore and always-show rules
- notification, refresh, and launch-at-login settings

## Notifications

DevPortal can request notification permission and notify when:

- a new web server or Docker-mapped port appears after the initial scan
- a web server has been running longer than the configured threshold

The default long-running threshold is 60 minutes.

## Launch At Login

The app uses `SMAppService.mainApp` for launch-at-login registration. The run
script ad-hoc signs the staged app bundle because ServiceManagement requires a
signed app.

## Docker

Docker actions include:

- open mapped host ports
- open `docker logs -f` in Terminal
- stop a container
- stop a Compose project when compose labels are available

## Privacy And Safety

DevPortal is local-first. It does not include analytics, telemetry, account
login, or cloud sync. It inspects local process, port, and Docker state using
macOS command-line tools and stores preferences in `UserDefaults`.

Read [docs/privacy.md](docs/privacy.md) for the full local data and command
surface.

## Repository Structure

```text
.
├── .github/                 # issue templates and CI/release workflows
├── docs/                    # architecture, packaging, privacy, troubleshooting
├── Resources/               # app icon assets
├── Sources/DevPortal/       # SwiftUI menu-bar app
├── Tests/DevPortalTests/    # Swift Testing coverage
└── script/                  # local build, packaging, and icon scripts
```

More detail is in [docs/architecture.md](docs/architecture.md) and
[docs/packaging.md](docs/packaging.md).

## Contributing

Contributions are welcome. Small fixes and docs updates can go straight to a PR.
For larger product or architecture changes, open an issue first so the behavior
can be agreed on before implementation.

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, testing, and PR expectations.

## License

DevPortal is licensed under the [MIT License](LICENSE).

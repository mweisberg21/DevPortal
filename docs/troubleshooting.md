# Troubleshooting

## The App Does Not Show In The Dock

DevPortal is a menu-bar app. Look for the terminal icon in the macOS menu bar.

## macOS Blocks The App

Early release builds may be unsigned or ad-hoc signed. Open **System Settings >
Privacy & Security** and choose **Open Anyway**, or build from source.

## Docker Is Missing

DevPortal shows Docker data only when Docker is installed and the `docker`
executable is available at one of the common locations:

- `/usr/local/bin/docker`
- `/opt/homebrew/bin/docker`
- `/usr/bin/docker`

## A Server Is Listed As Other Local Ports

DevPortal uses conservative classification. If a listener is not clearly a dev
server, it appears under **Other Local Ports**. Use an always-show rule if it is
important to keep visible.

## Stop Does Not Work

Graceful stop sends `SIGINT` only to processes owned by the current user. Some
tools ignore `SIGINT`, supervise child processes, or immediately restart. Use
Terminate only when you are sure the process should be killed.

## Launch At Login Does Not Enable

Launch-at-login uses `SMAppService.mainApp`, which requires a signed app bundle.
The local build script ad-hoc signs the app. For public releases, Developer ID
signing and notarization are planned.

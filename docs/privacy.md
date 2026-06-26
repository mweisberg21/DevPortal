# Privacy

DevPortal is local-first.

It does not include:

- analytics
- telemetry
- crash reporting
- account login
- cloud sync
- background network requests to DevPortal servers

## Local Data Inspected

DevPortal reads local machine state so it can show useful server information:

- listening TCP ports
- process IDs, names, commands, and parent process IDs
- process working directories when available
- Docker container names, images, status, labels, and mapped ports when Docker is installed
- git/package hints derived from local project folders

## Commands Used

DevPortal may run these local commands:

- `/usr/sbin/lsof`
- `/bin/ps`
- `docker ps`
- `docker stop`
- `docker compose stop`
- `docker logs -f`
- `/usr/bin/open`
- `/usr/bin/osascript`

Docker commands only run when Docker is installed and the user invokes Docker
actions, except `docker ps`, which is used during scans to list containers.

## Data Stored

DevPortal stores these values in macOS `UserDefaults`:

- preferences
- visibility rules
- server history
- first-seen timestamps used for runtime and stale-server notifications

## Network Behavior

Opening a detected server URL uses your default browser. DevPortal itself does
not proxy, upload, sync, or transmit local scanner results.

## Stopping Processes

DevPortal only stops processes when the user chooses a stop action. Web server
graceful stop sends `SIGINT`; termination sends `SIGTERM` after confirmation.
Docker stop actions call Docker for the selected container or Compose project.

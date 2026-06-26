# Changelog

All notable user-facing changes to DevPortal.

This project loosely follows [Keep a Changelog](https://keepachangelog.com).

## [Unreleased]

### Added

- Initial macOS menu-bar app for finding local dev servers, Docker ports, and other local listeners.
- Inspector window with search, runtime tracking, source hints, history, rules, notifications, and launch-at-login settings.
- Docker actions for opening mapped ports, opening logs, stopping containers, and stopping Compose projects.
- Release packaging support for `DevPortal.app` and `DevPortal.app.zip`.

### Changed

### Fixed

- Docker new-port notifications now ignore containers without mapped host ports.

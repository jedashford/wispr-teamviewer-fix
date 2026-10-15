# Changelog

This file lists all important changes to this project.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Each log line starts with the date and time, in the same format as `log show`. Thus you can compare the helper log with the TeamViewer log.
- README: steps for a paste that does not appear or shows old text. Wispr Flow puts the old clipboard back 0.5 seconds after the first read. Thus Cmd+V after a missed paste pastes the old text.

## [1.0.0] - 2026-10-13

### Added

- Background helper `wispr-teamviewer-fix.swift`. It makes Wispr Flow paste the full text into a TeamViewer remote-control window, not only the letter "v". Options: `--key cmd|ctrl`, `--wait`, `--gap`, and `--version`.
- `install.sh`. It installs the app at `~/Applications/WisprTeamViewerFix.app`, asks for Accessibility access, and adds a login service.
- `uninstall.sh`. It removes the app, the login service, the log file, and the Accessibility entry.
- `--windows` option for `install.sh`, for a remote Windows computer.
- `--selftest` self-check for the event-match rule. It needs no permissions.
- CI. It builds the helper and runs the self-check on macOS 14 and macOS 15. It runs ShellCheck on Ubuntu.

[Unreleased]: https://github.com/jedashford/wispr-teamviewer-fix/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/jedashford/wispr-teamviewer-fix/releases/tag/v1.0.0

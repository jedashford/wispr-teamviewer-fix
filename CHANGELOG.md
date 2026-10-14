# Changelog

This file lists all important changes to this project.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-10-13

### Added

- Background helper `wispr-teamviewer-fix.swift`. It makes Wispr Flow paste the full text into a TeamViewer remote-control window, not only the letter "v". Options: `--key cmd|ctrl`, `--wait`, `--gap`, and `--version`.
- `install.sh`. It installs the app at `~/Applications/WisprTeamViewerFix.app`, asks for Accessibility access, and adds a login service.
- `uninstall.sh`. It removes the app, the login service, the log file, and the Accessibility entry.
- `--windows` option for `install.sh`, for a remote Windows computer.
- `--selftest` self-check for the event-match rule. It needs no permissions.
- Terminal output for `install.sh`, `uninstall.sh`, and `doctor.sh` in `lib/ui.sh`: a logo, a spinner during the build, check lines (`✓`, `!`, `✗`), and a closing animation. `NO_COLOR`, `CI`, and `WTF_NO_ANIM` turn off colors or animation. Output that does not go to a terminal is plain text.
- `doctor.sh`. A read-only health check of the install. It prints a report for bug reports. Exit code 0 when no check fails, 1 when a check fails.
- `Makefile` with the targets `build`, `test` (default), `lint`, `install`, `uninstall`, `doctor`, and `clean`.
- CI. It builds a universal binary (arm64 and x86_64, deployment target macOS 13) and runs the self-check on macOS 14 and macOS 15. It runs ShellCheck and a Prettier check of the docs on Ubuntu.
- Release workflow. A pushed `vX.Y.Z` tag makes a GitHub release from the matching section of this file.
- Dependabot. It checks the GitHub Actions versions each week.
- Issue forms: bug report (asks for the output of `./doctor.sh`), compatibility report, and feature request.
- Animated terminal demo `docs/demo.svg` in the README.

[Unreleased]: https://github.com/jedashford/wispr-teamviewer-fix/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/jedashford/wispr-teamviewer-fix/releases/tag/v1.0.0

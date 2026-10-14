# Contribute to Wispr TeamViewer Fix

Thank you for your help. This guide tells you how to report bugs, propose changes, and test the helper.

## Report a bug

Do not report a security problem in a public issue. Read [SECURITY.md](SECURITY.md) first.

1. Open the [bug report form](https://github.com/jedashford/wispr-teamviewer-fix/issues/new?template=bug_report.yml).
2. Give the versions of macOS, TeamViewer, and the app that pastes the text (for example, Wispr Flow).
3. Give your Mac type (Apple Silicon or Intel) and the operating system of the remote computer.
4. Add the last 20 lines of the log to the report.

```bash
tail -n 20 ~/Library/Logs/wispr-teamviewer-fix.log
```

## Propose a change

1. For a large change, open an issue first. Describe the problem and your solution.
2. Fork the repository and make a branch from `main`.
3. Make your change.
4. Do the checks in [Build and test](#build-and-test).
5. Open a pull request against `main`.
6. Complete the checklist in the pull request template.

## Set up your Mac

1. Install the Apple Command Line Tools.

```bash
xcode-select --install
```

2. Install ShellCheck. This example uses Homebrew.

```bash
brew install shellcheck
```

3. Clone the repository.

```bash
git clone https://github.com/jedashford/wispr-teamviewer-fix.git
```

4. Go into the repository folder.

```bash
cd wispr-teamviewer-fix
```

## Build and test

1. Build the helper.

```bash
xcrun swiftc -O wispr-teamviewer-fix.swift -o wispr-teamviewer-fix
```

2. Run the self-check. The output must be `selftest ok`. The self-check needs no permissions.

```bash
./wispr-teamviewer-fix --selftest
```

3. Lint the shell scripts. ShellCheck must show no warnings.

```bash
shellcheck install.sh uninstall.sh
```

CI runs the same checks. It builds the helper and runs the self-check on macOS 14 and macOS 15. It runs ShellCheck on Ubuntu.

## Test with a real TeamViewer session

The self-check does not send real keyboard events. Do this manual test when your change affects keyboard events or delays.

You need a Mac with TeamViewer. TeamViewer must control another computer.

1. Install the helper.

```bash
./install.sh
```

2. When macOS asks, give Accessibility access to WisprTeamViewerFix.
3. Open a TeamViewer remote-control window.
4. Click a text box on the remote computer.
5. Dictate a sentence with Wispr Flow.
6. Make sure that the full text appears, not only the letter "v".
7. Make sure that the log contains `replayed paste with cmd`.

```bash
grep "replayed paste with cmd" ~/Library/Logs/wispr-teamviewer-fix.log
```

For a remote Windows computer, install with `./install.sh --windows`. The log line is then `replayed paste with ctrl`.

## Accessibility access after a rebuild

A changed build gets a new ad hoc signature. macOS then does not match the old Accessibility entry to the new build. The helper cannot read keyboard events until you give access again.

`install.sh` removes the old entry when the build changed. After you install a new build, do these steps:

1. When macOS asks for Accessibility access, give it again.
2. If macOS does not ask, open **System Settings → Privacy & Security → Accessibility**.
3. Turn on **WisprTeamViewerFix**.

## Pull request checklist

- [ ] `./wispr-teamviewer-fix --selftest` prints `selftest ok`.
- [ ] `shellcheck install.sh uninstall.sh` shows no warnings.
- [ ] If behavior changes, README.md describes the new behavior.
- [ ] CHANGELOG.md has an entry under `## [Unreleased]`.

## Help wanted

The maintainer tested the helper on macOS 26.6 Tahoe on Apple Silicon. The test used TeamViewer 15.69.4, Wispr Flow 1.6.1144, and a remote Mac.

The project needs test reports for these setups:

- Remote Windows computers (`./install.sh --windows`)
- Intel Macs
- macOS versions earlier than macOS 26
- Other paste apps: TextExpander, Keyboard Maestro, and Text Blaze

Open an issue with your setup and the result. A report that says "it works" also helps.

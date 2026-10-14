# Contribute to Wispr TeamViewer Fix

Thank you for your help. This guide tells you how to report bugs, propose changes, test the helper, and make a release.

## Report a bug

Do not report a security problem in a public issue. Read [SECURITY.md](SECURITY.md) first.

1. Run the doctor in the repository folder.
   ```bash
   ./doctor.sh
   ```
2. Open the [bug report form](https://github.com/jedashford/wispr-teamviewer-fix/issues/new?template=bug_report.yml).
3. Paste the output of `./doctor.sh`. The form requires it. The output contains no typed text and no clipboard contents.
4. Give the versions of macOS, TeamViewer, and the app that pastes the text (for example, Wispr Flow).
5. Give your Mac type (Apple Silicon or Intel) and the operating system of the remote computer.
6. Optional: add the last 20 lines of the log to the report.
   ```bash
   tail -n 20 ~/Library/Logs/wispr-teamviewer-fix.log
   ```

### Issue forms

| Form                                                                                                                    | Use it when                                                         | Asks for `./doctor.sh` output |
| ----------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- | ----------------------------- |
| [Bug report](https://github.com/jedashford/wispr-teamviewer-fix/issues/new?template=bug_report.yml)                     | The fix does not work.                                              | Yes (required)                |
| [Compatibility report](https://github.com/jedashford/wispr-teamviewer-fix/issues/new?template=compatibility_report.yml) | You tried a setup that is not tested yet. "Works" reports help too. | Yes (optional)                |
| [Feature request](https://github.com/jedashford/wispr-teamviewer-fix/issues/new?template=feature_request.yml)           | You want a new feature or a change.                                 | No                            |

For a security problem, use [private vulnerability reporting](https://github.com/jedashford/wispr-teamviewer-fix/security/advisories/new).

## Propose a change

1. For a large change, open an issue first. Describe the problem and your solution.
2. Fork the repository and make a branch from `main`.
3. Make your change.
4. Do the checks in [Build and test](#build-and-test).
5. Open a pull request against `main`.
6. Complete the [pull request checklist](#pull-request-checklist).

## Set up your Mac

1. Install the Apple Command Line Tools.
   ```bash
   xcode-select --install
   ```
2. Install ShellCheck and Node.js. Node.js runs Prettier through `npx`. This example uses Homebrew.
   ```bash
   brew install shellcheck node
   ```
3. Clone the repository.
   ```bash
   git clone https://github.com/jedashford/wispr-teamviewer-fix.git
   ```
4. Go into the repository folder.
   ```bash
   cd wispr-teamviewer-fix
   ```

## Repository layout

| Path                         | Purpose                                                                                                         |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `wispr-teamviewer-fix.swift` | The helper. One Swift file. It imports only Cocoa.                                                              |
| `install.sh`                 | Builds the helper, installs the app bundle, and starts the login service.                                       |
| `uninstall.sh`               | Removes all items that `install.sh` made.                                                                       |
| `doctor.sh`                  | Read-only health check. Exit code 0 when no check fails, 1 when a check fails.                                  |
| `lib/ui.sh`                  | Terminal output for the three scripts: logo, check lines, spinner, closing animation. Source it. Do not run it. |
| `Makefile`                   | Shortcuts for contributors.                                                                                     |
| `docs/`                      | Diagram (`how-it-works.svg`), animated demo (`demo.svg`), and screenshots.                                      |
| `.github/`                   | CI and release workflows, Dependabot, issue forms, and the pull request template.                               |

## Build and test

Use the `Makefile` targets. `make` with no target runs `make test`.

| Command          | What it runs                                                               |
| ---------------- | -------------------------------------------------------------------------- |
| `make build`     | `xcrun swiftc -O wispr-teamviewer-fix.swift -o build/wispr-teamviewer-fix` |
| `make test`      | `make build`, then `build/wispr-teamviewer-fix --selftest` and `--version` |
| `make lint`      | `shellcheck --severity=info install.sh uninstall.sh doctor.sh lib/ui.sh`   |
| `make install`   | `./install.sh`                                                             |
| `make uninstall` | `./uninstall.sh`                                                           |
| `make doctor`    | `./doctor.sh`                                                              |
| `make clean`     | `rm -rf build`                                                             |

Do these checks before you open a pull request:

1. Build the helper and run the self-check. The self-check needs no permissions.
   ```bash
   make test
   ```
   The output must contain `selftest ok` and `wispr-teamviewer-fix 1.0.0` (or the new version).
2. Lint the shell scripts. ShellCheck must show no messages.
   ```bash
   make lint
   ```
3. Check the format of the Markdown and YAML files.
   ```bash
   npx --yes prettier@3 --check "**/*.{md,yml}"
   ```
4. If the check finds problems, fix the format.
   ```bash
   npx --yes prettier@3 --write "**/*.{md,yml}"
   ```

`make build` and `make test` do not change the installed app. Only `make install` changes it.

### Terminal output

`install.sh`, `uninstall.sh` and `doctor.sh` print through the functions in `lib/ui.sh`. Use these functions for new output:

| Function                           | Output                                                                                                                           |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `ui_logo TEXT`                     | The logo and the tagline. The tagline ends with TEXT, for example `v1.0.0`.                                                      |
| `ui_ok MSG`                        | `✓ MSG` (green)                                                                                                                  |
| `ui_warn MSG`                      | `! MSG` (yellow)                                                                                                                 |
| `ui_fail MSG`                      | `✗ MSG` (red)                                                                                                                    |
| `ui_info MSG`                      | `· MSG` (dim)                                                                                                                    |
| `ui_spin MSG [SPIN_MSG] -- CMD...` | Runs CMD with a spinner. Then prints `✓ MSG (1.8s)`, or `✗ SPIN_MSG failed` and the output of CMD. Returns the exit code of CMD. |
| `ui_typewriter TEXT`               | Shows a lone "v" at a `remote>` prompt, then types TEXT over it.                                                                 |

Test a change to the output in three modes:

1. On a terminal: `./doctor.sh`
2. Without colors and animation: `NO_COLOR=1 ./doctor.sh`
3. Without a terminal: `./doctor.sh | cat`

## Continuous integration

The [CI workflow](.github/workflows/ci.yml) runs on each pull request and on each push to `main`.

| Job          | Runner                    | Steps                                                                                                                                                                                                                           |
| ------------ | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `build`      | `macos-14` and `macos-15` | Compiles for arm64 and x86_64 with deployment target macOS 13. Joins them into a universal binary with `lipo`. Checks both architectures. Runs `--selftest` and `--version`. Uploads the binary as a build artifact for 7 days. |
| `shellcheck` | `ubuntu-latest`           | `shellcheck --severity=info install.sh uninstall.sh doctor.sh lib/ui.sh`                                                                                                                                                        |
| `docs`       | `ubuntu-latest`           | `npx --yes prettier@3 --check "**/*.{md,yml}"`                                                                                                                                                                                  |

[Dependabot](.github/dependabot.yml) checks the GitHub Actions versions each week. Its pull requests use the commit prefix `ci`.

## Make a release

The [release workflow](.github/workflows/release.yml) starts when you push a tag that starts with `v`. It copies the matching section of `CHANGELOG.md` into the GitHub release notes.

1. In `CHANGELOG.md`, move the entries under `## [Unreleased]` to a new section `## [X.Y.Z] - YYYY-MM-DD`.
2. At the end of `CHANGELOG.md`, add a link for `[X.Y.Z]` and update the `[Unreleased]` link.
3. In `wispr-teamviewer-fix.swift`, set `let version = "X.Y.Z"`. The installer logo and `--version` read this value.
4. In `README.md`, set the **Version** row of the "At a glance" table.
5. Merge the change into `main`.
6. Make the tag and push it.
   ```bash
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

The workflow makes the release "Wispr TeamViewer Fix vX.Y.Z". If `CHANGELOG.md` has no `## [X.Y.Z]` section, the workflow fails and makes no release.

## Test with a real TeamViewer session

The self-check does not send real keyboard events. Do this manual test when your change affects keyboard events or delays.

You need a Mac with TeamViewer. TeamViewer must control another computer.

1. Install the helper.
   ```bash
   ./install.sh
   ```
2. When macOS asks, give Accessibility access to WisprTeamViewerFix.
3. Run the doctor. The last line must be `All checks passed. Paste this output into a bug report if you need help.`
   ```bash
   ./doctor.sh
   ```
4. Open a TeamViewer remote-control window.
5. Click a text box on the remote computer.
6. Dictate a sentence with Wispr Flow.
7. Make sure that the full text appears, not only the letter "v".
8. Make sure that the log contains `replayed paste with cmd`.
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
4. Run `./doctor.sh`. Make sure that it shows `✓ Accessibility access: on`.

If the build did not change, the installer shows `✓ Same build as before, Accessibility stays on`.

## Pull request checklist

- [ ] `make test` prints `selftest ok`.
- [ ] `make lint` shows no messages.
- [ ] `npx --yes prettier@3 --check "**/*.{md,yml}"` passes.
- [ ] If behavior changes, README.md describes the new behavior.
- [ ] CHANGELOG.md has an entry under `## [Unreleased]`.

## Help wanted

The maintainer tested the helper on macOS 26.6 Tahoe on Apple Silicon. The test used TeamViewer 15.69.4, Wispr Flow 1.6.1144, and a remote Mac.

CI builds a universal binary on macOS 14 and macOS 15. CI does not run the helper with real keyboard events. The project needs test reports for these setups:

- Remote Windows computers (`./install.sh --windows`)
- Intel Macs
- macOS versions earlier than macOS 26
- Other paste apps: TextExpander, Keyboard Maestro, and Text Blaze

Send your setup and the result with the [compatibility report form](https://github.com/jedashford/wispr-teamviewer-fix/issues/new?template=compatibility_report.yml). A report that says "it works" also helps.

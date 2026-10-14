# Security policy

## Supported versions

| Version | Supported |
| ------- | --------- |
| 1.0.x   | Yes       |

## Report a vulnerability

Do not report a vulnerability in a public issue. Use GitHub private vulnerability reporting.

1. Open the [Security tab](https://github.com/jedashford/wispr-teamviewer-fix/security) of the repository.
2. Click **Report a vulnerability**.
3. Describe the problem, the affected version, and the steps to reproduce it.

The direct link is https://github.com/jedashford/wispr-teamviewer-fix/security/advisories/new.

The maintainer will reply within 7 days.

## What this tool can access

- **Permission:** Accessibility only. The helper needs it to read and post keyboard events.
- **Network:** The helper contains no network code.
- **Clipboard:** The helper never reads the clipboard contents.
- **Log:** The helper writes to `~/Library/Logs/wispr-teamviewer-fix.log`. The log records only Cmd+V events that occur while TeamViewer is the front app.
- **Log contents:** Each event line contains the source process ID and the state of the physical Command key. The log also records start and permission messages.
- **User:** The helper runs as the logged-in user, not as root.
- **Login service:** `~/Library/LaunchAgents/io.github.jedashford.wispr-teamviewer-fix.plist` starts the helper when you log in.
- **Signature:** The app at `~/Applications/WisprTeamViewerFix.app` has an ad hoc signature.

To remove the helper, run the uninstall script.

```bash
./uninstall.sh
```

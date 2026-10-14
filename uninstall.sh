#!/bin/bash
# Remove Wispr TeamViewer Fix and everything install.sh created.
set -euo pipefail

ID="io.github.jedashford.wispr-teamviewer-fix"
APP="$HOME/Applications/WisprTeamViewerFix.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

launchctl bootout "gui/$(id -u)/$ID" 2>/dev/null || true
# tccutil finds the app by bundle ID, so remove the Accessibility entry before the app.
if [ -d "$APP" ]; then
  "$LSREGISTER" -f "$APP" || true
  tccutil reset Accessibility "$ID" >/dev/null 2>&1 || true
  "$LSREGISTER" -u "$APP" || true
fi
rm -rf "$APP" "$HOME/Library/LaunchAgents/$ID.plist" "$HOME/Library/Logs/wispr-teamviewer-fix.log"

echo "Wispr TeamViewer Fix is removed. You can delete this folder now."

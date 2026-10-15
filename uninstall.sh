#!/bin/bash
# Remove Wispr TeamViewer Fix and everything install.sh created.
set -euo pipefail

# shellcheck source=lib/ui.sh
. "$(dirname "$0")/lib/ui.sh"

ID="io.github.jedashford.wispr-teamviewer-fix"
APP="$HOME/Applications/WisprTeamViewerFix.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

ui_logo "$(ui_installed_version "$APP/Contents/MacOS/wispr-teamviewer-fix")"

if launchctl bootout "gui/$(id -u)/$ID" 2>/dev/null; then
  ui_ok "Stopped the login service"
else
  ui_info "The login service was not running"
fi
# tccutil finds the app by bundle ID, so remove the Accessibility entry before the app.
if [ -d "$APP" ]; then
  "$LSREGISTER" -f "$APP" || true
  if tccutil reset Accessibility "$ID" >/dev/null 2>&1; then
    ui_ok "Removed the Accessibility entry"
  else
    ui_warn "Could not remove the Accessibility entry. Remove it in System Settings → Privacy & Security → Accessibility."
  fi
  "$LSREGISTER" -u "$APP" || true
fi
rm -rf "$APP" "$HOME/Library/LaunchAgents/$ID.plist" "$HOME/Library/Logs/wispr-teamviewer-fix.log"
ui_ok "Removed $(ui_path "$APP"), the service file and the log"

echo
echo "  Wispr TeamViewer Fix is removed. You can delete this folder now."

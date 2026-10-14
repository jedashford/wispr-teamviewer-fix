#!/bin/bash
# Check the Wispr TeamViewer Fix install and print a report you can paste into a bug report.
# It only reads. It changes nothing. Exit code: 0 when no check fails, 1 when a check fails.
set -euo pipefail

# shellcheck source=lib/ui.sh
. "$(dirname "$0")/lib/ui.sh"

ID="io.github.jedashford.wispr-teamviewer-fix"
NAME="WisprTeamViewerFix"
APP="$HOME/Applications/$NAME.app"
BIN="$APP/Contents/MacOS/wispr-teamviewer-fix"
PLIST="$HOME/Library/LaunchAgents/$ID.plist"
LOG="$HOME/Library/Logs/wispr-teamviewer-fix.log"
PROBLEMS=0

problem() {
  ui_fail "$1"
  PROBLEMS=$((PROBLEMS + 1))
}
section() { printf '  %s%s%s\n' "$C_BOLD" "$1" "$C_RESET"; }
finish() {
  echo
  if [ "$PROBLEMS" -eq 0 ]; then
    echo "  All checks passed. Paste this output into a bug report if you need help."
    exit 0
  fi
  echo "  $PROBLEMS problem(s) found. See the hints above."
  exit 1
}

VERSION=$(ui_installed_version "$BIN")
ui_logo "$VERSION"

section "System"
if [ "$(uname)" != Darwin ]; then
  problem "Wispr TeamViewer Fix runs only on macOS."
  finish
fi
ui_ok "macOS $(sw_vers -productVersion) on $(uname -m)"
for app in "TeamViewer" "Wispr Flow"; do
  if v=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "/Applications/$app.app/Contents/Info.plist" 2>/dev/null); then
    ui_ok "$app $v"
  else
    ui_warn "$app not found in /Applications"
  fi
done

section "Helper"
if [ "$VERSION" = "not installed" ]; then
  problem "Not installed. Run ./install.sh"
  finish
fi
ui_ok "Installed: $(ui_path "$APP") (${VERSION#v})"

if svc=$(launchctl print "gui/$(id -u)/$ID" 2>/dev/null); then
  state=$(awk '$1 == "state" { print $3; exit }' <<<"$svc")
  pid=$(awk '$1 == "pid" { print $3; exit }' <<<"$svc")
  if [ "$state" = running ]; then
    ui_ok "Login service loaded, running (pid $pid)"
  else
    problem "Login service loaded, but ${state:-not running}. launchd retries every 10 s. See the log below."
  fi
else
  problem "Login service not loaded. Run ./install.sh"
fi

# The last start line in the log wins: the helper writes "Waiting..." until access is on, then "running".
last=$(grep -E 'running|Waiting' "$LOG" 2>/dev/null | tail -n 1) || last=''
case "$last" in
  *running*) ui_ok "Accessibility access: on" ;;
  *Waiting*) problem "Accessibility access: off. Turn on $NAME in System Settings → Privacy & Security → Accessibility" ;;
  *) ui_warn "Accessibility access: unknown. The log has no start line." ;;
esac

if [ -f "$PLIST" ]; then
  key=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments" "$PLIST" 2>/dev/null |
    awk 'f { print $1; f = 0 } $1 == "--key" { f = 1 }') || key=''
  ui_ok "Remote paste key: ${key:-cmd}"
else
  problem "Service file missing: $(ui_path "$PLIST"). Run ./install.sh"
fi

section "Recent log"
if [ -s "$LOG" ]; then
  tail -n 5 "$LOG" | while IFS= read -r line; do ui_info "$line"; done
else
  ui_info "(empty)"
fi

finish

#!/bin/bash
# Build Wispr TeamViewer Fix, install it as a login service, and ask for Accessibility access.
#   ./install.sh            the remote computer is a Mac (it pastes with Cmd+V)
#   ./install.sh --windows  the remote computer runs Windows (it pastes with Ctrl+V)
set -euo pipefail

# shellcheck source=lib/ui.sh
. "$(dirname "$0")/lib/ui.sh"

ID="io.github.jedashford.wispr-teamviewer-fix"
NAME="WisprTeamViewerFix"
APP="$HOME/Applications/$NAME.app"
EXE="wispr-teamviewer-fix"
PLIST="$HOME/Library/LaunchAgents/$ID.plist"
LOG="$HOME/Library/Logs/$EXE.log"
DOMAIN="gui/$(id -u)"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

case "${1:-}" in
  "") KEY=cmd PASTE="Cmd+V" ;;
  --windows) KEY=ctrl PASTE="Ctrl+V" ;;
  *)
    echo "Usage: ./install.sh [--windows]" >&2
    echo "  --windows  the remote computer runs Windows (it pastes with Ctrl+V)" >&2
    exit 1
    ;;
esac

# The logo shows the version of the source that this script builds.
ui_logo "v$(sed -n 's/^let version = "\(.*\)"$/\1/p' "$(dirname "$0")/$EXE.swift")"

[ "$(uname)" = Darwin ] || {
  ui_fail "Wispr TeamViewer Fix runs only on macOS."
  exit 1
}
ui_ok "macOS $(sw_vers -productVersion) on $(uname -m)"
if ! xcrun --find swiftc >/dev/null 2>&1; then
  ui_fail "Swift is missing"
  echo "    Install Apple's Command Line Tools in the window that opens."
  echo "    When that install is done, run ./install.sh again."
  xcode-select --install 2>/dev/null || true
  exit 1
fi
ui_ok "Swift $(xcrun swiftc --version 2>&1 | sed -n '/Apple Swift version/{s/.*Apple Swift version \([0-9.]*\).*/\1/p;q;}')"

cd "$(dirname "$0")"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

mkdir -p "$BUILD/$NAME.app/Contents/MacOS"
ui_spin "Built helper" "Building helper" -- xcrun swiftc -O "$EXE.swift" -o "$BUILD/$NAME.app/Contents/MacOS/$EXE"
cat >"$BUILD/$NAME.app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$ID</string>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleExecutable</key><string>$EXE</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$("$BUILD/$NAME.app/Contents/MacOS/$EXE" --version | cut -d' ' -f2)</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF
codesign --force --sign - "$BUILD/$NAME.app" 2>/dev/null || { ui_fail "Could not sign the app"; exit 1; }
"$BUILD/$NAME.app/Contents/MacOS/$EXE" --selftest >/dev/null || {
  ui_fail "Self-check failed. Nothing was installed. Please open an issue with the output above."
  exit 1
}
ui_ok "Self-check passed"

# Stop the old copy before replacing it.
if launchctl bootout "$DOMAIN/$ID" 2>/dev/null; then sleep 1; fi

if cmp -s "$BUILD/$NAME.app/Contents/MacOS/$EXE" "$APP/Contents/MacOS/$EXE"; then
  ui_ok "Same build as before, Accessibility stays on"
else
  mkdir -p "$HOME/Applications"
  rm -rf "$APP"
  mv "$BUILD/$NAME.app" "$APP"
  # Register the app so tccutil can find it by bundle ID.
  "$LSREGISTER" -f "$APP" || true
  # A new build has a new signature, so an old Accessibility grant no longer matches it.
  tccutil reset Accessibility "$ID" >/dev/null 2>&1 || true
  ui_ok "Installed $(ui_path "$APP")"
fi

mkdir -p "$(dirname "$PLIST")" "$(dirname "$LOG")"
cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$ID</string>
  <key>ProgramArguments</key>
  <array>
    <string>$APP/Contents/MacOS/$EXE</string>
    <string>--key</string><string>$KEY</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>10</integer>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF
: >"$LOG"
launchctl bootstrap "$DOMAIN" "$PLIST" || {
  ui_fail "Could not start the login service. Run ./doctor.sh to see why."
  exit 1
}
ui_ok "Login service started (remote pastes with $PASTE)"
sleep 2

echo
if grep -q "running" "$LOG"; then
  ui_ok "Running. It starts each time you log in."
  echo
  ui_typewriter "Hello from Wispr Flow. Every word arrives."
else
  ui_warn "One step left: give $NAME Accessibility access."
  echo "    1. In the window from macOS, click \"Open System Settings\"."
  echo "    2. Turn on the switch next to $NAME."
  echo "    The Accessibility page opens now."
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
fi
echo
printf '  %sLog:%s %s\n' "$C_DIM" "$C_RESET" "$(ui_path "$LOG")"

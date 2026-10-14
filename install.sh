#!/bin/bash
# Build Wispr TeamViewer Fix, install it as a login service, and ask for Accessibility access.
#   ./install.sh            the remote computer is a Mac (it pastes with Cmd+V)
#   ./install.sh --windows  the remote computer runs Windows (it pastes with Ctrl+V)
set -euo pipefail

ID="io.github.jedashford.wispr-teamviewer-fix"
NAME="WisprTeamViewerFix"
APP="$HOME/Applications/$NAME.app"
EXE="wispr-teamviewer-fix"
PLIST="$HOME/Library/LaunchAgents/$ID.plist"
LOG="$HOME/Library/Logs/$EXE.log"
DOMAIN="gui/$(id -u)"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

case "${1:-}" in
  "") KEY=cmd ;;
  --windows) KEY=ctrl ;;
  *) echo "Usage: ./install.sh [--windows]"; exit 1 ;;
esac

[ "$(uname)" = Darwin ] || { echo "Wispr TeamViewer Fix runs only on macOS."; exit 1; }
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Swift is missing. Install Apple's Command Line Tools in the window that opens."
  echo "When that install is done, run ./install.sh again."
  xcode-select --install 2>/dev/null || true
  exit 1
fi

cd "$(dirname "$0")"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

echo "Building..."
mkdir -p "$BUILD/$NAME.app/Contents/MacOS"
xcrun swiftc -O "$EXE.swift" -o "$BUILD/$NAME.app/Contents/MacOS/$EXE"
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
codesign --force --sign - "$BUILD/$NAME.app" 2>/dev/null
"$BUILD/$NAME.app/Contents/MacOS/$EXE" --selftest

# Stop the old copy before replacing it.
launchctl bootout "$DOMAIN/$ID" 2>/dev/null && sleep 1 || true

if cmp -s "$BUILD/$NAME.app/Contents/MacOS/$EXE" "$APP/Contents/MacOS/$EXE"; then
  echo "Same build as before. Your Accessibility access stays on."
else
  mkdir -p "$HOME/Applications"
  rm -rf "$APP"
  mv "$BUILD/$NAME.app" "$APP"
  # Register the app so tccutil can find it by bundle ID.
  "$LSREGISTER" -f "$APP" || true
  # A new build has a new signature, so an old Accessibility grant no longer matches it.
  tccutil reset Accessibility "$ID" >/dev/null 2>&1 || true
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
launchctl bootstrap "$DOMAIN" "$PLIST"
sleep 2

echo
if grep -q "running" "$LOG"; then
  echo "Done. Wispr TeamViewer Fix is running and starts each time you log in."
else
  echo "Installed. One step is left: give $NAME Accessibility access."
  echo "  1. In the window from macOS, click \"Open System Settings\"."
  echo "  2. Turn on the switch next to $NAME."
  echo "If no window appears, use the Accessibility page that opens now."
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
fi
echo "Log: $LOG"

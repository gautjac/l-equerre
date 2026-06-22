#!/usr/bin/env bash
# install.sh — build, sign, and install L'Équerre into /Applications in one shot.
#
# Signing: project.yml sets DEVELOPMENT_TEAM, so xcodebuild signs with your real
# Apple Development identity automatically. That's a STABLE code signature, so the
# Accessibility permission you grant once PERSISTS across reinstalls — unlike
# ad-hoc signing, whose cdhash changes every build and makes macOS TCC drop the
# grant (and often refuse to list the app at all).
#
# Usage:
#   ./install.sh                 build + install + (re)launch
#   ./install.sh --reset-perms   also wipe the Accessibility grant (forces a fresh prompt)
#
# DerivedData is kept OUT of any iCloud-synced folder — codesign rejects the
# extended attributes iCloud stamps ("resource fork … not allowed").
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="LEquerre"
BUNDLE_ID="app.atelier.lequerre"
DEST="/Applications/${APP_NAME}.app"
DD="${LEQUERRE_MAC_DD:-/tmp/l-equerre-mac-dd}"
XCODEGEN="$(command -v xcodegen || echo /opt/homebrew/bin/xcodegen)"

RESET_PERMS=0
[[ "${1:-}" == "--reset-perms" ]] && RESET_PERMS=1

echo "==> Generating Xcode project…"
"$XCODEGEN" generate >/dev/null

echo "==> Building Release (signed via DEVELOPMENT_TEAM in project.yml)…"
xcodebuild -project "${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath "$DD" build >/dev/null

APP="$DD/Build/Products/Release/${APP_NAME}.app"
[[ -d "$APP" ]] || { echo "!! Build product missing at $APP" >&2; exit 1; }

# Guard against a silent regression to ad-hoc signing, which would break the
# persistent Accessibility grant.
if codesign -dvvv "$APP" 2>&1 | grep -q "adhoc"; then
  echo "!! WARNING: build is AD-HOC signed — the Accessibility grant will NOT persist."
  echo "   Check DEVELOPMENT_TEAM in project.yml and 'security find-identity -p codesigning'."
fi

echo "==> Quitting any running instance…"
osascript -e "tell application \"${APP_NAME}\" to quit" 2>/dev/null || true
pkill -f "${DEST}/Contents/MacOS/" 2>/dev/null || true
sleep 1

echo "==> Installing to ${DEST}…"
rm -rf "$DEST"
cp -R "$APP" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

if [[ "$RESET_PERMS" == "1" ]]; then
  echo "==> Resetting the Accessibility grant (a fresh prompt will appear)…"
  tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
fi

echo "==> Adding to Login Items (launch at login)…"
osascript >/dev/null 2>&1 <<OSA || true
tell application "System Events"
  if not (exists login item "${APP_NAME}") then
    make login item at end with properties {path:"${DEST}", hidden:false}
  end if
end tell
OSA

echo "==> Launching…"
open "$DEST"

cat <<EOF

────────────────────────────────────────────────────────────────────────────
 L'Équerre installed → ${DEST}  (look for the set-square glyph in the menu bar)

 First install (or after --reset-perms): grant Accessibility once —
   System Settings → Privacy & Security → Accessibility → enable L'Équerre.
 Window managers need this to move other apps' windows. The grant PERSISTS
 across reinstalls because the build is signed with your Apple Development cert.
────────────────────────────────────────────────────────────────────────────
EOF

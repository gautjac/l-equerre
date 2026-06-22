#!/usr/bin/env bash
# Build L'Équerre (Debug) for native macOS, sign it, and launch it.
#
# L'Équerre is a menu-bar window manager. It needs the Accessibility permission
# to move other apps' windows — the app's onboarding screen walks you through
# granting it on first run (System Settings → Privacy & Security → Accessibility).
#
# Keep DerivedData OUT of any iCloud-synced folder or `codesign` fails
# ("resource fork … not allowed").
set -euo pipefail
cd "$(dirname "$0")"

DD="${LEQUERRE_MAC_DD:-/tmp/l-equerre-mac-dd}"   # DerivedData OUTSIDE iCloud

echo "==> Generating project…"
{ ./gen.sh >/dev/null 2>&1 || xcodegen generate >/dev/null; }

echo "==> Building (Debug) + signing for macOS…"
xcodebuild -project LEquerre.xcodeproj -scheme "LEquerre" \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$DD" build

APP="$DD/Build/Products/Debug/LEquerre.app"
[[ -d "$APP" ]] || { echo "Build product not found at $APP" >&2; exit 1; }

echo "==> Launching $APP"
open "$APP"

echo
echo "==> L'Équerre (macOS) launched — look for the set-square glyph in the menu bar."
echo "    First run will ask for the Accessibility permission; grant it in"
echo "    System Settings → Privacy & Security → Accessibility, then the grid opens."

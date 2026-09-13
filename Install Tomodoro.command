#!/bin/bash
#
# Double-click this file to install Tomodoro.
#
# It copies Tomodoro.app into your own Applications folder (no administrator
# password needed), clears the download flag macOS adds to files from the
# internet, and starts the app. Nothing else on your Mac is touched.
#
# To uninstall: quit Tomodoro from its menu, then drag Tomodoro out of your
# Applications folder.

set -u

echo ""
echo "  Tomodoro installer"
echo "  ------------------"
echo ""

HERE="$(cd "$(dirname "$0")" && pwd)"
DESTINATION="$HOME/Applications"

# Look for the app next to this script, in a dist folder, or in Xcode's build
# output. The newest matching build wins.
APP=""
for candidate in "$HERE/Tomodoro.app" "$HERE/dist/Tomodoro.app"; do
  if [ -d "$candidate" ]; then APP="$candidate"; break; fi
done
if [ -z "$APP" ]; then
  APP="$(ls -dt "$HOME"/Library/Developer/Xcode/DerivedData/Tomodoro-*/Build/Products/*/Tomodoro.app 2>/dev/null | head -1)"
fi

if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo "  I could not find Tomodoro.app."
  echo ""
  echo "  Put this installer in the same folder as Tomodoro.app and try again,"
  echo "  or build the app first (see README.md)."
  echo ""
  read -r -p "  Press Return to close."
  exit 1
fi

echo "  Found:  $APP"

# Quit a running copy so the new one can replace it.
if pgrep -f "Tomodoro.app/Contents/MacOS/Tomodoro" >/dev/null 2>&1; then
  echo "  Stopping the copy that is already running..."
  pkill -f "Tomodoro.app/Contents/MacOS/Tomodoro" >/dev/null 2>&1
  sleep 1
fi

mkdir -p "$DESTINATION"
rm -rf "$DESTINATION/Tomodoro.app"

echo "  Installing into $DESTINATION ..."
if ! cp -R "$APP" "$DESTINATION/Tomodoro.app"; then
  echo ""
  echo "  The copy failed. Try again, or drag Tomodoro.app into your"
  echo "  Applications folder yourself."
  echo ""
  read -r -p "  Press Return to close."
  exit 1
fi

# Files that arrive from the internet carry a quarantine flag. This app is not
# signed with a paid Apple certificate, so that flag would make macOS refuse to
# open it. Clearing it here saves the right-click-Open dance.
xattr -dr com.apple.quarantine "$DESTINATION/Tomodoro.app" 2>/dev/null

echo "  Starting Tomodoro..."
open "$DESTINATION/Tomodoro.app"

echo ""
echo "  Done. Look for the little tortoise at the top right of your screen,"
echo "  next to the clock."
echo ""
echo "  To have it start automatically when you log in:"
echo "    System Settings > General > Login Items > add Tomodoro"
echo ""
read -r -p "  Press Return to close this window."

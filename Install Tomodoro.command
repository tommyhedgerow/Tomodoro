#!/bin/bash
#
# Double-click this file to build and install Tomodoro.
#
# It builds the app from the sources in this folder whenever Xcode is available,
# copies it into your own Applications folder (no administrator password
# needed), clears the download flag macOS adds to files from the internet, and
# starts it. Nothing else on your Mac is touched.
#
# If there is nothing to build — you were handed the app rather than the source,
# or Xcode is not installed — it installs a Tomodoro.app it finds next to this
# script, in dist/, or in Xcode's build output instead.
#
# To uninstall: quit Tomodoro from its menu, then drag Tomodoro out of your
# Applications folder.
#
# Two settings exist for scripted use; ignore them when double-clicking:
#   TOMODORO_DESTINATION=/somewhere/Applications   where the app is installed
#   TOMODORO_CONFIGURATION=Debug                   which build configuration

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
DESTINATION="${TOMODORO_DESTINATION:-$HOME/Applications}"
CONFIGURATION="${TOMODORO_CONFIGURATION:-Release}"
BUILD_DIR="$HERE/.build/DerivedData"
BUILD_LOG="$HERE/.build/install-build.log"

# Prints each line of the argument indented, so multi-line messages line up.
say() { while IFS= read -r line; do printf '  %s\n' "$line"; done <<< "$1"; }
blank() { printf '\n'; }

fail() {
  blank
  say "$1"
  blank
  read -r -p "  Press Return to close this window."
  exit 1
}

has_xcode() { command -v xcodebuild >/dev/null 2>&1; }
has_sources() { [ -d "$HERE/Sources" ]; }

blank
say "Tomodoro installer"
say "------------------"

APP=""

# ---------------------------------------------------------------- build ------

if has_sources && has_xcode; then
  blank
  say "Building from the sources in this folder ($CONFIGURATION)."

  # The Xcode project is generated, so refresh it when XcodeGen is around.
  # Without it, an existing Tomodoro.xcodeproj is used exactly as it is.
  if command -v xcodegen >/dev/null 2>&1; then
    say "  Refreshing the Xcode project..."
    (cd "$HERE" && xcodegen generate) >/dev/null 2>&1 \
      || say "  (XcodeGen could not run; using the project as it is.)"
  fi

  if [ ! -d "$HERE/Tomodoro.xcodeproj" ]; then
    fail "The Xcode project is missing and XcodeGen is not installed, so there is
nothing to build. Install XcodeGen, then double-click this file again:

  brew install xcodegen"
  fi

  say "  Compiling. The first build takes a couple of minutes — please wait."
  mkdir -p "$HERE/.build"
  STARTED=$SECONDS
  if ! (cd "$HERE" && xcodebuild \
          -project Tomodoro.xcodeproj \
          -scheme Tomodoro \
          -configuration "$CONFIGURATION" \
          -derivedDataPath "$BUILD_DIR" \
          build) > "$BUILD_LOG" 2>&1
  then
    blank
    say "The build failed. The end of the log:"
    blank
    tail -n 15 "$BUILD_LOG" | sed 's/^/    /'
    blank
    fail "Everything Xcode said is in:
  $BUILD_LOG"
  fi

  APP="$BUILD_DIR/Build/Products/$CONFIGURATION/Tomodoro.app"
  say "  Built in $((SECONDS - STARTED))s."
fi

# ---------------------------------------------------------- find an app ------

if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  if has_sources && has_xcode; then
    fail "The build finished but produced no Tomodoro.app. See $BUILD_LOG"
  fi

  blank
  if has_sources; then
    say "There are sources here, but no Xcode, so I cannot build them. Install"
    say "Xcode from the App Store — it is a large download — and double-click"
    say "this file again."
  else
    say "There is nothing to build here, so I will install a Tomodoro.app."
  fi
  blank

  # Next to the installer first, then a dist folder, then whatever Xcode last
  # built (newest first, so a fresh build always wins over an old one).
  for candidate in "$HERE/Tomodoro.app" "$HERE/dist/Tomodoro.app"; do
    if [ -d "$candidate" ]; then APP="$candidate"; break; fi
  done
  if [ -z "$APP" ]; then
    APP="$(ls -dt "$BUILD_DIR"/Build/Products/*/Tomodoro.app \
                   "$HOME"/Library/Developer/Xcode/DerivedData/Tomodoro-*/Build/Products/*/Tomodoro.app \
                   2>/dev/null | head -1)"
  fi

  if [ -z "$APP" ] || [ ! -d "$APP" ]; then
    fail "I could not find a Tomodoro.app to install, and there was nothing here
to build one from.

Put this installer in the same folder as Tomodoro.app (or in a folder holding
dist/Tomodoro.app) and double-click it again. To build from source, install
Xcode and XcodeGen (brew install xcodegen) and double-click it here."
  fi
fi

# ------------------------------------------------------------ install -------

blank
say "Installing:"
say "  $APP"

# Quit a running copy so the new one can replace it.
if pgrep -f "Tomodoro.app/Contents/MacOS/Tomodoro" >/dev/null 2>&1; then
  blank
  say "Quitting the copy that is already running..."
  pkill -f "Tomodoro.app/Contents/MacOS/Tomodoro" >/dev/null 2>&1
  sleep 1
fi

blank
say "Copying into $DESTINATION ..."
mkdir -p "$DESTINATION"
rm -rf "$DESTINATION/Tomodoro.app"
if ! cp -R "$APP" "$DESTINATION/Tomodoro.app"; then
  fail "The copy failed. Try again, or drag Tomodoro.app into your Applications
folder by hand."
fi

# Files that arrive from the internet carry a quarantine flag. This app is not
# signed with a paid Apple certificate, so that flag would make macOS refuse to
# open it. Clearing it here saves the right-click-Open dance.
xattr -dr com.apple.quarantine "$DESTINATION/Tomodoro.app" 2>/dev/null

say "Starting Tomodoro..."
open "$DESTINATION/Tomodoro.app"

blank
say "Done. Look for the little tortoise at the top right of your screen,"
say "next to the clock."
blank
say "To have it start automatically when you log in:"
say "  System Settings > General > Login Items > add Tomodoro"
blank
read -r -p "  Press Return to close this window."

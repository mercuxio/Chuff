#!/bin/bash
# Builds RailwayMonitor.app in this folder.
#   ./build.sh            build only
#   ./build.sh --install  build, copy to /Applications and launch
#
# Follows Squiggle's scripts/package-app.sh: SwiftPM makes a bare executable,
# so the bundle is assembled by hand, Sparkle.framework is embedded and given
# an rpath, and nested code is signed before the outer bundle. Signing is
# ad-hoc (`-`), fine for local use; a downloaded copy is quarantined.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"

APP_NAME="RailwayMonitor"
APP="$ROOT/$APP_NAME.app"

echo "→ Compiling (release)…"
# Swift 6.4's default "swiftbuild" backend fails to start with Command Line
# Tools only ("Unknown error parsing property list") — Squiggle uses the
# native build system for the same reason.
swift build --build-system native -c release --product "$APP_NAME" \
    2> >(grep -v "has been deprecated" >&2)
BIN_DIR="$(swift build --build-system native -c release --show-bin-path 2>/dev/null)"

echo "→ Assembling $APP_NAME.app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
# The icon comes prebuilt from scripts/make-icon.sh (which needs Xcode's actool).
cp "$ROOT/Resources/Assets.car" "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Sparkle. `cp -R` keeps the framework's version symlinks as symlinks.
SPARKLE="$ROOT/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [ ! -d "$SPARKLE" ]; then
    echo "Sparkle.framework not found at $SPARKLE" >&2
    exit 1
fi
cp -R "$SPARKLE" "$APP/Contents/Frameworks/"

# The executable lives in Contents/MacOS and the framework in
# Contents/Frameworks; without this the app dies on launch with
# "Library not loaded: @rpath/Sparkle.framework".
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/$APP_NAME"

echo "→ Signing (ad-hoc, local use)…"
# Nested code first, outer bundle second — the order codesign requires.
codesign --force --deep --sign - "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$APP"
codesign --verify --strict --deep "$APP"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
echo "✓ Built $APP_NAME $VERSION at $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x "$APP_NAME" 2>/dev/null || true
    # Wait (up to ~5s) for the old copy to exit, or `open` fails with -600.
    for _ in $(seq 1 25); do pgrep -x "$APP_NAME" >/dev/null || break; sleep 0.2; done
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" "/Applications/"
    open "/Applications/$APP_NAME.app"
    echo "✓ Installed to /Applications and launched"
fi

#!/usr/bin/env bash
# Ported from Squiggle's scripts/appcast.sh.
#
# Adds the packaged zip for the current version to appcast.xml, signed with the
# EdDSA key in the login Keychain (the same key Squiggle and Sniffcast use).
# Run after ./build.sh and after the zip exists, then commit and push
# appcast.xml: installed copies read it from the main branch on GitHub.
#
# Release steps:
#   1. bump CFBundleShortVersionString and CFBundleVersion in Resources/Info.plist
#   2. ./build.sh
#   3. ditto -c -k --keepParent RailwayMonitor.app build/RailwayMonitor-<version>.zip
#   4. scripts/appcast.sh
#   5. create GitHub release v<version> with that zip attached; commit + push appcast.xml
#
# The signature covers the zip, so this must run on the exact file uploaded.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
PLIST="RailwayMonitor.app/Contents/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
MINOS=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$PLIST" 2>/dev/null || echo 14.0)
ZIP="build/RailwayMonitor-$VERSION.zip"
if [ ! -f "$ZIP" ]; then
  echo "$ZIP not found — build it with: ditto -c -k --keepParent RailwayMonitor.app $ZIP" >&2
  exit 1
fi
SIGN=$(.build/artifacts/sparkle/Sparkle/bin/sign_update "$ZIP")
URL="https://github.com/mercuxio/RailwayMonitor/releases/download/v$VERSION/RailwayMonitor-$VERSION.zip"
NOTES="https://github.com/mercuxio/RailwayMonitor/releases/tag/v$VERSION"
DATE=$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")

ITEM="    <item>
      <title>Railway Monitor $VERSION</title>
      <pubDate>$DATE</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MINOS</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>$NOTES</sparkle:releaseNotesLink>
      <enclosure url=\"$URL\" type=\"application/octet-stream\" $SIGN/>
    </item>"

grep -q "<sparkle:shortVersionString>$VERSION<" appcast.xml && { echo "appcast.xml already lists $VERSION"; exit 0; }
python3 - "$ITEM" <<'P'
import sys
item=sys.argv[1]; s=open('appcast.xml').read()
s=s.replace("<title>Railway Monitor</title>\n","<title>Railway Monitor</title>\n"+item+"\n",1)  # newest first
open('appcast.xml','w').write(s)
P
echo "Added $VERSION to appcast.xml"

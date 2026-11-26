#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
LUME_SIGNING_IDENTITY="-" ./scripts/build-app.sh > /dev/null

mkdir -p dist
ZIP="dist/Lume-$VERSION.zip"
rm -f "$ZIP" "$ZIP.sha256"
ditto -c -k --keepParent build/Lume.app "$ZIP"
(cd dist && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256")

echo "$ZIP"
cat "$ZIP.sha256"
echo
echo "Para publicar:"
echo "  gh release create v$VERSION $ZIP $ZIP.sha256 --title \"Lume $VERSION\" --generate-notes"

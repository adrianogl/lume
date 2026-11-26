#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release

APP="build/Lume.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Lume "$APP/Contents/MacOS/Lume"
cp Resources/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
xcrun actool Resources/AppIcon.icon \
  --compile "$APP/Contents/Resources" \
  --app-icon AppIcon \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --output-partial-info-plist "$(mktemp)" \
  > /dev/null
SIGNING_IDENTITY="${LUME_SIGNING_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ { print $2; exit }')}"
codesign --force --sign "${SIGNING_IDENTITY:--}" "$APP"

echo "$APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Lume || true
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/Lume.app"
  cp -R "$APP" "$HOME/Applications/"
  open "$HOME/Applications/Lume.app"
  echo "Instalado em ~/Applications/Lume.app"
fi

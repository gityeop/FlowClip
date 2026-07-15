#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="FlowClip"
BUNDLE_ID="com.gityeop.FlowClip"
TEAM_ID="79Q5RV23F9"
SIGNING_IDENTITY="Developer ID Application: Sang Yeop Lim ($TEAM_ID)"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"

case "$MODE" in
  run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify)
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac

if /usr/bin/pgrep -x "$APP_NAME" >/dev/null; then
  /usr/bin/pkill -x "$APP_NAME"
fi

xcodebuild -quiet \
  -project "$ROOT_DIR/Maccy.xcodeproj" \
  -scheme Maccy \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_STYLE=Manual \
  "CODE_SIGN_IDENTITY=$SIGNING_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  build

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    /usr/bin/lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    if ! /usr/bin/pgrep -x "$APP_NAME"; then
      echo "$APP_NAME failed to launch" >&2
      exit 1
    fi
    ;;
esac

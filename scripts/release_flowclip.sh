#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLIST_PATH="$ROOT_DIR/Maccy/Info.plist"
APPCAST_PATH="$ROOT_DIR/appcast.xml"
ZIP_PATH="$ROOT_DIR/build/FlowClip.zip"
NOTARIZE_SCRIPT="$ROOT_DIR/scripts/notarize.sh"
TAP_REPO_URL="https://github.com/gityeop/homebrew-flowclip.git"
TAP_CASK_PATH="Casks/flowclip.rb"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release_flowclip.sh \
    --version 1.0.9 \
    --build 10 \
    --notes-file /path/to/release_notes.md \
    --html-notes-file /path/to/release_notes_appcast.html

Optional:
  --skip-notarize        Skip ./scripts/notarize.sh
  --skip-homebrew        Skip Homebrew tap update
  --pub-date "<RFC2822>" Override appcast pubDate

Environment variable equivalents:
  FLOWCLIP_VERSION
  FLOWCLIP_BUILD
  FLOWCLIP_NOTES_FILE
  FLOWCLIP_HTML_NOTES_FILE
  FLOWCLIP_PUB_DATE
  FLOWCLIP_SKIP_NOTARIZE=1
  FLOWCLIP_SKIP_HOMEBREW=1
EOF
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: required command not found: $cmd" >&2
    exit 1
  fi
}

prompt_if_empty() {
  local var_name="$1"
  local prompt="$2"
  local value="${!var_name:-}"
  if [[ -z "$value" ]]; then
    read -r -p "$prompt" value
    printf -v "$var_name" '%s' "$value"
  fi
}

VERSION="${FLOWCLIP_VERSION:-}"
BUILD="${FLOWCLIP_BUILD:-}"
NOTES_FILE="${FLOWCLIP_NOTES_FILE:-}"
HTML_NOTES_FILE="${FLOWCLIP_HTML_NOTES_FILE:-}"
PUB_DATE="${FLOWCLIP_PUB_DATE:-$(date '+%a, %d %b %Y %H:%M:%S %z')}"
SKIP_NOTARIZE="${FLOWCLIP_SKIP_NOTARIZE:-0}"
SKIP_HOMEBREW="${FLOWCLIP_SKIP_HOMEBREW:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --build)
      BUILD="$2"
      shift 2
      ;;
    --notes-file)
      NOTES_FILE="$2"
      shift 2
      ;;
    --html-notes-file)
      HTML_NOTES_FILE="$2"
      shift 2
      ;;
    --pub-date)
      PUB_DATE="$2"
      shift 2
      ;;
    --skip-notarize)
      SKIP_NOTARIZE=1
      shift
      ;;
    --skip-homebrew)
      SKIP_HOMEBREW=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

prompt_if_empty VERSION "Version (e.g. 1.0.9): "
prompt_if_empty BUILD "Build number (e.g. 10): "
prompt_if_empty NOTES_FILE "Markdown release notes file path: "
prompt_if_empty HTML_NOTES_FILE "Appcast HTML notes file path: "

if [[ ! -f "$PLIST_PATH" ]]; then
  echo "error: missing Info.plist at $PLIST_PATH" >&2
  exit 1
fi

if [[ ! -f "$APPCAST_PATH" ]]; then
  echo "error: missing appcast.xml at $APPCAST_PATH" >&2
  exit 1
fi

if [[ ! -f "$NOTES_FILE" ]]; then
  echo "error: markdown notes file not found: $NOTES_FILE" >&2
  exit 1
fi

if [[ ! -f "$HTML_NOTES_FILE" ]]; then
  echo "error: appcast HTML notes file not found: $HTML_NOTES_FILE" >&2
  exit 1
fi

require_command /usr/libexec/PlistBuddy
require_command shasum
require_command stat
require_command gh
require_command git
require_command sed
require_command awk

echo "==> Setting version/build in Info.plist to $VERSION ($BUILD)"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST_PATH"

if [[ "$SKIP_NOTARIZE" != "1" ]]; then
  echo "==> Running notarization script"
  (cd "$ROOT_DIR" && "$NOTARIZE_SCRIPT")
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "error: expected release artifact not found: $ZIP_PATH" >&2
  exit 1
fi

SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
SIZE_BYTES="$(stat -f%z "$ZIP_PATH")"
TAG="v$VERSION"
RELEASE_URL="https://github.com/gityeop/FlowClip/releases/download/$TAG/FlowClip.zip"
RELEASE_PAGE="https://github.com/gityeop/FlowClip/releases/tag/$TAG"

echo "==> Artifact metadata"
echo "    SHA256: $SHA256"
echo "    Size:   $SIZE_BYTES bytes"

ITEM_FILE="$(mktemp)"
APPCAST_TMP="$(mktemp)"
TAP_DIR=""

cleanup() {
  rm -f "$ITEM_FILE" "$APPCAST_TMP"
  if [[ -n "$TAP_DIR" && -d "$TAP_DIR" ]]; then
    rm -rf "$TAP_DIR"
  fi
}
trap cleanup EXIT

{
  cat <<EOF
    <item>
      <title>$VERSION</title>
      <description>
        <![CDATA[
EOF
  cat "$HTML_NOTES_FILE"
  cat <<EOF
        ]]>
      </description>
      <pubDate>$PUB_DATE</pubDate>
      <releaseNotesLink>$RELEASE_PAGE</releaseNotesLink>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url="$RELEASE_URL"
        sparkle:version="$BUILD"
        sparkle:shortVersionString="$VERSION"
        length="$SIZE_BYTES"
        type="application/octet-stream" />
    </item>
EOF
} > "$ITEM_FILE"

echo "==> Updating appcast.xml"
awk -v item_file="$ITEM_FILE" '
  BEGIN { inserted = 0 }
  /<item>/ && inserted == 0 {
    while ((getline line < item_file) > 0) print line
    close(item_file)
    inserted = 1
  }
  { print }
  END {
    if (inserted == 0) {
      while ((getline line < item_file) > 0) print line
      close(item_file)
    }
  }
' "$APPCAST_PATH" > "$APPCAST_TMP"
mv "$APPCAST_TMP" "$APPCAST_PATH"

echo "==> Committing release changes"
(cd "$ROOT_DIR" && git add -A && git commit -m "release: $TAG")

echo "==> Pushing release commit"
(cd "$ROOT_DIR" && git push origin master)

echo "==> Creating GitHub release $TAG"
if gh release view "$TAG" >/dev/null 2>&1; then
  gh release upload "$TAG" "$ZIP_PATH" --clobber
  gh release edit "$TAG" --title "$TAG" --notes-file "$NOTES_FILE"
else
  gh release create "$TAG" "$ZIP_PATH" --title "$TAG" --notes-file "$NOTES_FILE"
fi

if [[ "$SKIP_HOMEBREW" != "1" ]]; then
  echo "==> Updating Homebrew tap"
  TAP_DIR="$(mktemp -d)"
  git clone "$TAP_REPO_URL" "$TAP_DIR"
  sed -i '' -E \
    -e "s/^  version \".*\"/  version \"$VERSION\"/" \
    -e "s/^  sha256 \".*\"/  sha256 \"$SHA256\"/" \
    "$TAP_DIR/$TAP_CASK_PATH"
  git -C "$TAP_DIR" add "$TAP_CASK_PATH"
  if git -C "$TAP_DIR" diff --cached --quiet; then
    echo "    Homebrew tap already up to date"
  else
    git -C "$TAP_DIR" commit -m "update: FlowClip $TAG"
    git -C "$TAP_DIR" push origin main
  fi
fi

echo "==> Release complete"
echo "    Version: $VERSION"
echo "    Build:   $BUILD"
echo "    Tag:     $TAG"
echo "    Notes:   $RELEASE_PAGE"

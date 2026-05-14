#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE="${1:-}"
OUTPUT_DMG="${2:-}"
VOLUME_NAME="${3:-MediaDownloader}"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

[[ -n "$APP_BUNDLE" && -n "$OUTPUT_DMG" ]] || fail "usage: $0 /path/App.app /path/App.dmg [VolumeName]"
[[ -d "$APP_BUNDLE" ]] || fail "app bundle does not exist: $APP_BUNDLE"

require_command hdiutil
require_command ditto

APP_NAME="$(basename "$APP_BUNDLE")"
OUTPUT_DIR="$(dirname "$OUTPUT_DMG")"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DMG="$(cd "$OUTPUT_DIR" && pwd)/$(basename "$OUTPUT_DMG")"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/media-downloader-dmg.XXXXXX")"
STAGING_DIR="$TMP_ROOT/staging"
MOUNT_DIR="$TMP_ROOT/mount"
RW_DMG="$TMP_ROOT/$VOLUME_NAME-rw.dmg"
MOUNTED=false

cleanup() {
  if [[ "$MOUNTED" == "true" ]]; then
    hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$STAGING_DIR" "$MOUNT_DIR"
/usr/bin/ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -quiet \
  -fs HFS+ \
  -format UDRW \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  "$RW_DMG"

hdiutil attach "$RW_DMG" \
  -quiet \
  -readwrite \
  -noverify \
  -noautoopen \
  -mountpoint "$MOUNT_DIR"
MOUNTED=true

if [[ "${SKIP_DMG_FINDER_LAYOUT:-false}" != "true" ]]; then
  /usr/bin/osascript <<APPLESCRIPT >/dev/null 2>&1 || true
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {100, 100, 650, 420}
    set arrangement of icon view options of container window to not arranged
    set icon size of icon view options of container window to 96
    set text size of icon view options of container window to 13
    set position of item "$APP_NAME" of container window to {165, 175}
    set position of item "Applications" of container window to {415, 175}
    close
    update without registering applications
  end tell
end tell
APPLESCRIPT
fi

sync
hdiutil detach "$MOUNT_DIR" -quiet
MOUNTED=false

rm -f "$OUTPUT_DMG"
hdiutil convert "$RW_DMG" \
  -quiet \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$OUTPUT_DMG"

printf '%s\n' "$OUTPUT_DMG"

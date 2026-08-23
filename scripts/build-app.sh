#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Focus Veil"
EXECUTABLE_NAME="FocusVeil"
VERSION="0.1.0"
BUILD_NUMBER="1"
DIST_DIR="$PROJECT_ROOT/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
ARCHIVE_PATH="$DIST_DIR/Focus-Veil-$VERSION.zip"
DMG_PATH="$DIST_DIR/Focus-Veil-$VERSION.dmg"
INFO_PLIST="$PROJECT_ROOT/Resources/Info.plist"
STAGING_DIR=""

cleanup() {
    if [[ -n "$STAGING_DIR" && -d "$STAGING_DIR" ]]; then
        rm -rf "$STAGING_DIR"
    fi
}

trap cleanup EXIT

cd "$PROJECT_ROOT"

swift test
swift build -c release --arch arm64
swift build -c release --arch x86_64

ARM64_BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
X86_64_BIN_DIR="$(swift build -c release --arch x86_64 --show-bin-path)"
ARM64_EXECUTABLE="$ARM64_BIN_DIR/$EXECUTABLE_NAME"
X86_64_EXECUTABLE="$X86_64_BIN_DIR/$EXECUTABLE_NAME"

if [[ ! -x "$ARM64_EXECUTABLE" || ! -x "$X86_64_EXECUTABLE" ]]; then
    echo "error: one or more release architecture slices are missing" >&2
    exit 1
fi

if [[ ! -f "$INFO_PLIST" ]]; then
    echo "error: Info.plist not found at $INFO_PLIST" >&2
    exit 1
fi

mkdir -p "$DIST_DIR"
rm -rf "$APP_BUNDLE" "$ARCHIVE_PATH" "$DMG_PATH"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
lipo -create \
    "$ARM64_EXECUTABLE" \
    "$X86_64_EXECUTABLE" \
    -output "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
cp "$INFO_PLIST" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP_BUNDLE/Contents/Info.plist"

SIGNING_IDENTITY="${FOCUS_VEIL_SIGNING_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
    SIGNING_IDENTITY="$(
        security find-identity -v -p codesigning 2>/dev/null \
            | awk -F '"' '/"Apple Development: / { print $2; exit }'
    )"
fi

if [[ -n "$SIGNING_IDENTITY" ]]; then
    echo "Signing with $SIGNING_IDENTITY."
else
    SIGNING_IDENTITY="-"
    echo "warning: no Apple Development signing identity found; using ad-hoc signing." >&2
    echo "warning: Accessibility approval may need to be granted again after rebuilds." >&2
fi

SIGNING_OPTIONS=(--options runtime --timestamp=none)
if [[ "$SIGNING_IDENTITY" == "Developer ID Application:"* ]]; then
    SIGNING_OPTIONS=(--options runtime --timestamp)
fi

codesign --force --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE_PATH"

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/focus-veil-dmg.XXXXXX")"
ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -format UDZO \
    -ov \
    "$DMG_PATH" >/dev/null

if [[ "$SIGNING_IDENTITY" == "Developer ID Application:"* ]]; then
    codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"
fi

hdiutil verify "$DMG_PATH" >/dev/null

ARCHITECTURES="$(lipo -archs "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME")"
if [[ "$ARCHITECTURES" != *arm64* || "$ARCHITECTURES" != *x86_64* ]]; then
    echo "error: expected a universal arm64 and x86_64 executable" >&2
    exit 1
fi

echo "Built $APP_BUNDLE (version $VERSION, build $BUILD_NUMBER)."
echo "Architectures: $ARCHITECTURES."
echo "Created $ARCHIVE_PATH."
echo "Created $DMG_PATH."

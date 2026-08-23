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
INFO_PLIST="$PROJECT_ROOT/Resources/Info.plist"

cd "$PROJECT_ROOT"

swift test
swift build -c release --arch arm64

BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
EXECUTABLE_PATH="$BIN_DIR/$EXECUTABLE_NAME"

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
    echo "error: release executable not found at $EXECUTABLE_PATH" >&2
    exit 1
fi

if [[ ! -f "$INFO_PLIST" ]]; then
    echo "error: Info.plist not found at $INFO_PLIST" >&2
    exit 1
fi

mkdir -p "$DIST_DIR"
rm -rf "$APP_BUNDLE" "$ARCHIVE_PATH"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$EXECUTABLE_PATH" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
cp "$INFO_PLIST" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP_BUNDLE/Contents/Info.plist"

SIGNING_IDENTITY="$(
    security find-identity -v -p codesigning 2>/dev/null \
        | awk -F '"' '/"Apple Development: / { print $2; exit }'
)"

if [[ -n "$SIGNING_IDENTITY" ]]; then
    echo "Signing with the installed Apple Development identity."
else
    SIGNING_IDENTITY="-"
    echo "warning: no Apple Development signing identity found; using ad-hoc signing." >&2
    echo "warning: Accessibility approval may need to be granted again after rebuilds." >&2
fi

codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp=none "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE_PATH"

echo "Built $APP_BUNDLE (version $VERSION, build $BUILD_NUMBER)."
echo "Created $ARCHIVE_PATH."

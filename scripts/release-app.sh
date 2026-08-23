#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="0.1.0"
TAG="v$VERSION"
APP_NAME="Focus Veil"
DIST_DIR="$PROJECT_ROOT/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/Focus-Veil-$VERSION.dmg"
CHECKSUM_PATH="$DIST_DIR/SHA256SUMS.txt"
NOTARY_RESULT_PATH="$DIST_DIR/notarization-result.json"
RELEASE_NOTES_PATH="$PROJECT_ROOT/RELEASE_NOTES.md"
PUBLISH=false

if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--publish" ) ]]; then
    echo "Usage: $(basename "$0") [--publish]" >&2
    exit 64
fi

if [[ ${1:-} == "--publish" ]]; then
    PUBLISH=true
fi

SIGNING_IDENTITY="${FOCUS_VEIL_SIGNING_IDENTITY:-$(
    security find-identity -v -p codesigning 2>/dev/null \
        | awk -F '"' '/"Developer ID Application: / { print $2; exit }'
)}"
NOTARY_PROFILE="${FOCUS_VEIL_NOTARY_PROFILE:-}"

if [[ -z "$SIGNING_IDENTITY" ]]; then
    echo "error: no Developer ID Application identity is installed." >&2
    echo "Create or import one, or set FOCUS_VEIL_SIGNING_IDENTITY." >&2
    exit 1
fi

if [[ -z "$NOTARY_PROFILE" ]]; then
    echo "error: FOCUS_VEIL_NOTARY_PROFILE is required." >&2
    echo "Store credentials with: xcrun notarytool store-credentials <profile>" >&2
    exit 1
fi

export FOCUS_VEIL_SIGNING_IDENTITY="$SIGNING_IDENTITY"
"$PROJECT_ROOT/scripts/build-app.sh"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
hdiutil verify "$DMG_PATH" >/dev/null

if ! xcrun notarytool submit \
    "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait \
    --output-format json >"$NOTARY_RESULT_PATH"
then
    echo "error: notarization submission failed; see $NOTARY_RESULT_PATH" >&2
    exit 1
fi

NOTARY_STATUS="$(plutil -extract status raw "$NOTARY_RESULT_PATH")"
if [[ "$NOTARY_STATUS" != "Accepted" ]]; then
    echo "error: notarization status is $NOTARY_STATUS; see $NOTARY_RESULT_PATH" >&2
    exit 1
fi

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess \
    --type open \
    --context context:primary-signature \
    --verbose=2 \
    "$DMG_PATH"

(
    cd "$DIST_DIR"
    shasum -a 256 "$(basename "$DMG_PATH")" >"$(basename "$CHECKSUM_PATH")"
)

if [[ "$PUBLISH" == true ]]; then
    cd "$PROJECT_ROOT"

    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "error: commit all changes before publishing a release" >&2
        exit 1
    fi

    if git rev-parse "$TAG" >/dev/null 2>&1; then
        if [[ "$(git rev-list -n 1 "$TAG")" != "$(git rev-parse HEAD)" ]]; then
            echo "error: $TAG already points to a different commit" >&2
            exit 1
        fi
    else
        git tag -a "$TAG" -m "$APP_NAME $VERSION"
    fi

    git push origin "$TAG"
    gh release create \
        "$TAG" \
        "$DMG_PATH#$APP_NAME $VERSION universal installer" \
        "$CHECKSUM_PATH#SHA-256 checksum" \
        --repo alialfredji/focus-veil \
        --title "$APP_NAME $VERSION" \
        --notes-file "$RELEASE_NOTES_PATH"
fi

echo "Release artifact: $DMG_PATH"
echo "Checksum: $CHECKSUM_PATH"
if [[ "$PUBLISH" == true ]]; then
    echo "Published https://github.com/alialfredji/focus-veil/releases/tag/$TAG"
fi

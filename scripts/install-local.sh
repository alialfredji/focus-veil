#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Focus Veil"
EXECUTABLE_NAME="FocusVeil"
DIST_APP="$PROJECT_ROOT/dist/$APP_NAME.app"
INSTALL_PATH="/Applications/$APP_NAME.app"

if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--skip-build" ) ]]; then
    echo "Usage: $(basename "$0") [--skip-build]" >&2
    exit 64
fi

if pgrep -x "$EXECUTABLE_NAME" >/dev/null; then
    echo "error: Focus Veil is running. Quit it before installing." >&2
    exit 1
fi

if [[ ${1:-} != "--skip-build" ]]; then
    "$PROJECT_ROOT/scripts/build-app.sh"
elif [[ ! -d "$DIST_APP" ]]; then
    echo "error: $DIST_APP is missing. Run without --skip-build first." >&2
    exit 1
fi

codesign --verify --deep --strict "$DIST_APP"
rm -rf "$INSTALL_PATH"
ditto "$DIST_APP" "$INSTALL_PATH"
codesign --verify --deep --strict "$INSTALL_PATH"
open "$INSTALL_PATH"

echo "Installed and launched $INSTALL_PATH."

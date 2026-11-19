#!/bin/bash
# Removes "Open in Herdr.app" and resets its permission to control Finder.
# The Finder toolbar button must be removed by hand: hold Command (⌘) and drag
# it off the toolbar.
#
# Usage:  ./uninstall.sh
# Env:    INSTALL_DIR  where the app was installed (default: ~/Applications)

set -euo pipefail

APP_NAME="Open in Herdr"
BUNDLE_ID="dev.local.open-in-herdr"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
DEST="$INSTALL_DIR/$APP_NAME.app"

if [ ! -e "$DEST" ]; then
    echo "Nothing to remove: $DEST does not exist."
    exit 0
fi

existing_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$DEST/Contents/Info.plist" 2>/dev/null || true)
if [ "$existing_id" != "$BUNDLE_ID" ]; then
    echo "error: $DEST is not an Open in Herdr install; leaving it alone" >&2
    exit 1
fi

rm -rf "$DEST"
tccutil reset AppleEvents "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "Removed: $DEST"
echo "Remove the toolbar button by holding Command (⌘) and dragging it off the toolbar."

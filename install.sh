#!/bin/bash
# Installs "Open in Herdr.app": a Finder toolbar button that opens the front
# Finder window's folder as a new tab in Herdr (https://herdr.dev).
#
# The app is built on this Mac (not downloaded), so Gatekeeper does not block
# it, and its icon is copied from the Herdr.app already installed here.
#
# Usage:  ./install.sh
#         curl -fsSL <raw URL of this file> | bash
# Env:    INSTALL_DIR  where to put the app (default: ~/Applications)

set -euo pipefail

APP_NAME="Open in Herdr"
BUNDLE_ID="dev.local.open-in-herdr"
HERDR_ID="dev.herdr.app"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
DEST="$INSTALL_DIR/$APP_NAME.app"

die() { echo "error: $*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "this installer only runs on macOS"
for tool in osacompile codesign /usr/libexec/PlistBuddy; do
    command -v "$tool" >/dev/null || die "missing $tool"
done

# Locate Herdr by bundle id, wherever it is installed
HERDR_APP=$(osascript -e "POSIX path of (path to application id \"$HERDR_ID\")" 2>/dev/null) \
    || die "Herdr is not installed (install it from https://herdr.dev first)"
HERDR_APP="${HERDR_APP%/}"

# Refuse to replace anything at the destination that is not a previous install
if [ -e "$DEST" ]; then
    existing_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$DEST/Contents/Info.plist" 2>/dev/null || true)
    [ "$existing_id" = "$BUNDLE_ID" ] || die "$DEST exists and is not an Open in Herdr install; move it away first"
fi

STAGE=$(mktemp -d "${TMPDIR:-/tmp}/open-in-herdr.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT

cat > "$STAGE/main.applescript" <<'APPLESCRIPT'
-- Open in Herdr: Finder toolbar button.
-- Opens the front Finder window's folder as a new tab in Herdr's current space.

on run
	set targetPath to my frontFinderPath()
	set herdrBin to my herdrBinary()

	-- Start Herdr if its window is not running yet, then wait for it to answer.
	if not my herdrReady(herdrBin) then
		do shell script "open -b dev.herdr.app"
		set waited to 0
		repeat until my herdrReady(herdrBin)
			delay 0.5
			set waited to waited + 0.5
			if waited >= 15 then
				display alert "Open in Herdr" message "Herdr did not start in time."
				return
			end if
		end repeat
	end if

	try
		do shell script quoted form of herdrBin & " do tab.new --folder " & quoted form of targetPath
	on error
		-- No space to add a tab to (e.g. a freshly started window): start a space instead.
		try
			do shell script quoted form of herdrBin & " do space.new --folder " & quoted form of targetPath
		on error errMsg
			display alert "Open in Herdr" message errMsg
			return
		end try
	end try

	tell application id "dev.herdr.app" to activate
end run

on frontFinderPath()
	tell application "Finder"
		try
			set targetFolder to (target of front Finder window) as alias
		on error
			-- No Finder window open (or a window without a folder): use the Desktop.
			set targetFolder to (path to desktop folder)
		end try
	end tell
	return POSIX path of targetFolder
end frontFinderPath

on herdrBinary()
	set appPath to POSIX path of (path to application id "dev.herdr.app")
	return appPath & "Contents/MacOS/Herdr"
end herdrBinary

on herdrReady(herdrBin)
	try
		do shell script quoted form of herdrBin & " status >/dev/null 2>&1"
		return true
	on error
		return false
	end try
end herdrReady
APPLESCRIPT

echo "Building $APP_NAME.app..."
APP="$STAGE/$APP_NAME.app"
osacompile -o "$APP" "$STAGE/main.applescript" 2>&1 | { grep -v "replacing existing signature" || true; } >&2
[ -d "$APP" ] || die "osacompile failed"

PLIST="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$PLIST"
# Run without a Dock icon
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$PLIST"

# Use Herdr's own icon. osacompile also writes Assets.car + CFBundleIconName with
# the default script icon, which macOS prefers over applet.icns, so drop both.
icon=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$HERDR_APP/Contents/Info.plist" 2>/dev/null || true)
icon="${icon%.icns}"
if [ -n "$icon" ] && [ -f "$HERDR_APP/Contents/Resources/$icon.icns" ]; then
    cp "$HERDR_APP/Contents/Resources/$icon.icns" "$APP/Contents/Resources/applet.icns"
    rm -f "$APP/Contents/Resources/Assets.car"
    /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$PLIST" 2>/dev/null || true
else
    echo "warning: Herdr icon not found; keeping the default script icon" >&2
fi

# Editing the bundle invalidates osacompile's signature; re-sign ad hoc
codesign --force --deep -s - "$APP" 2>&1 | { grep -v "replacing existing signature" || true; } >&2
codesign -v "$APP" || die "signing failed"

mkdir -p "$INSTALL_DIR"
rm -rf "$DEST"
mv "$APP" "$DEST"
touch "$DEST"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST" || true

echo "Installed: $DEST"
echo
echo "Next steps:"
echo "  1. Hold Command (⌘) and drag the app onto a Finder window's toolbar."
echo "  2. Click it once and allow it to control Finder when macOS asks."
echo "  Tip: right-click the toolbar > Icon Only hides the button's text label."

# Show the app in Finder, ready to drag
open -R "$DEST" 2>/dev/null || true

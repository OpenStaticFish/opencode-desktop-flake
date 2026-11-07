#!/usr/bin/env bash
set -euo pipefail

wrapped=$1
unwrapped=$2
system=$3
version=$4

test -x "$wrapped/bin/opencode-desktop"
test -x "$unwrapped/bin/opencode-desktop-unwrapped"

case "$system" in
  *-linux)
    desktop="$wrapped/share/applications/ai.opencode.desktop.desktop"
    test -x "$unwrapped/opt/OpenCode/ai.opencode"
    test -x "$unwrapped/opt/OpenCode/resources/opencode-cli"
    test "$(cat "$unwrapped/opt/OpenCode/resources/opencode-cli.version")" = "$version"
    test -f "$wrapped/share/icons/hicolor/128x128/apps/ai.opencode.png"
    grep -Fxq "Exec=$wrapped/bin/opencode-desktop %U" "$desktop"
    grep -Fxq 'Icon=ai.opencode' "$desktop"
    ;;
  *-darwin)
    app="$wrapped/Applications/OpenCode.app"
    test -x "$app/Contents/MacOS/OpenCode"
    test -f "$app/Contents/Info.plist"
    test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" = "$version"
    ;;
  *)
    echo "Unsupported system: $system" >&2
    exit 1
    ;;
esac

echo "Package layout verified for $system (OpenCode $version)"

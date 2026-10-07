#!/usr/bin/env sh
set -eu
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
. "$CONFIG_DIR/colors.sh"
export ITEM_BG ITEM_BG_STRONG ITEM_BORDER BLUE TEXT ACTIVE_TEXT SUBTEXT GREEN YELLOW RED
# macOS pgrep excludes ancestors by default; the bar is this script's ancestor.
bar_pid="$(/usr/bin/pgrep -a -x sketchybar | /usr/bin/head -1)"
[ -n "$bar_pid" ] || exit 1
"$CONFIG_DIR/helpers/native_motion" --ensure "$bar_pid"

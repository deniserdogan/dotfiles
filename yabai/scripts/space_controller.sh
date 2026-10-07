#!/usr/bin/env sh
# The committed/pending palette wins over stale environment inherited by bar
# plugins after an appearance switch. Hover continues in its separate daemon.
unset THEME_MODE
. "$HOME/.config/sketchybar/colors.sh"
export ITEM_BG ITEM_BG_STRONG ITEM_BORDER BLUE TEXT ACTIVE_TEXT SUBTEXT
exec "$HOME/.config/sketchybar/helpers/space_controller" "$@"

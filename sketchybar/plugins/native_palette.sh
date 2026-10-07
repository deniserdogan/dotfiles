#!/usr/bin/env sh
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
. "$CONFIG_DIR/colors.sh"
sketchybar --trigger native_palette_changed \
  ITEM_BG="$ITEM_BG" ITEM_BG_STRONG="$ITEM_BG_STRONG" \
  ITEM_BORDER="$ITEM_BORDER" BLUE="$BLUE" TEXT="$TEXT" \
  ACTIVE_TEXT="$ACTIVE_TEXT" SUBTEXT="$SUBTEXT" \
  GREEN="$GREEN" YELLOW="$YELLOW" RED="$RED"

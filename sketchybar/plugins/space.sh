#!/usr/bin/env sh

. "$CONFIG_DIR/colors.sh"

if [ "$SELECTED" = "true" ]; then
  sketchybar --animate sin 7 \
    --set "$NAME" \
      background.color="$BLUE" \
      background.border_color="$BLUE" \
      icon.color="$ACTIVE_TEXT" \
      label.color="$ACTIVE_TEXT"
else
  sketchybar --animate sin 7 \
    --set "$NAME" \
      background.color="$ITEM_BG" \
      background.border_color="$ITEM_BORDER" \
      icon.color="$TEXT" \
      label.color="$SUBTEXT"
fi

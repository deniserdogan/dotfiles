#!/usr/bin/env sh

. "$CONFIG_DIR/colors.sh"

[ -n "$INFO" ] || exit 0

icon="$("$CONFIG_DIR/plugins/icon_map.sh" "$INFO")"

# A short sine transition keeps rapid app cycling lively without the slow
# rubber-band effect of the previous twelve-frame easing.
sketchybar --animate sin 6 \
  --set "$NAME" \
    icon="$icon" \
    icon.width=29 \
    icon.background.image="" \
    label="$INFO" \
    label.color="$TEXT"

#!/usr/bin/env sh

. "$CONFIG_DIR/colors.sh"

[ -n "$INFO" ] || exit 0

icon="$("$CONFIG_DIR/plugins/icon_map.sh" "$INFO")"
image="$("$CONFIG_DIR/plugins/icon_map.sh" "$INFO" --image)"
image_drawing=off
[ -n "$image" ] && image_drawing=on

# A short sine transition keeps rapid app cycling lively without the slow
# rubber-band effect of the previous twelve-frame easing.
sketchybar --animate sin 6 \
  --set "$NAME" \
    icon="$icon" \
    icon.width=29 \
    icon.background.drawing="$image_drawing" \
    icon.background.image="$image" \
    icon.background.image.scale=0.5 \
    icon.background.image.padding_left=6 \
    label="$INFO" \
    label.color="$TEXT"

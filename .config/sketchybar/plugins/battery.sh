#!/usr/bin/env sh

. "$CONFIG_DIR/colors.sh"

status="$(pmset -g batt)"
percentage="$(printf '%s' "$status" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')"
[ -n "$percentage" ] || exit 0

if printf '%s' "$status" | grep -q 'AC Power'; then
  icon="󰂄"
  color="$GREEN"
elif [ "$percentage" -ge 80 ]; then
  icon="󰁹"
  color="$GREEN"
elif [ "$percentage" -ge 60 ]; then
  icon="󰂀"
  color="$TEAL"
elif [ "$percentage" -ge 40 ]; then
  icon="󰁾"
  color="$YELLOW"
elif [ "$percentage" -ge 20 ]; then
  icon="󰁼"
  color="$PEACH"
else
  icon="󰁺"
  color="$RED"
fi

sketchybar --set "$NAME" \
  icon="$icon" \
  icon.color="$color" \
  label="${percentage}%"

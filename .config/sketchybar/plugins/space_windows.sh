#!/usr/bin/env sh

[ "$SENDER" = "space_windows_change" ] || exit 0

space="$(printf '%s' "$INFO" | jq -r '.space // empty')"
[ -n "$space" ] || exit 0

apps="$(printf '%s' "$INFO" | jq -r '.apps | keys[]?' 2>/dev/null)"
icon_strip=""

if [ -n "$apps" ]; then
  while IFS= read -r app; do
    [ -n "$app" ] || continue
    icon="$("$CONFIG_DIR/plugins/icon_map.sh" "$app")"
    if [ -z "$icon_strip" ]; then
      icon_strip="$icon"
    else
      icon_strip="$icon_strip  $icon"
    fi
  done <<EOF
$apps
EOF
else
  icon_strip=""
fi

if [ -n "$icon_strip" ]; then
  sketchybar --animate tanh 14 \
    --set "space.$space" label="$icon_strip" label.drawing=on
else
  sketchybar --animate tanh 14 \
    --set "space.$space" label="" label.drawing=off
fi

sketchybar --trigger yabai_stack_changed

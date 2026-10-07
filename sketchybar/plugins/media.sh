#!/usr/bin/env sh

. "$CONFIG_DIR/colors.sh"

player="/opt/homebrew/bin/nowplaying-cli"
[ -x "$player" ] || {
  sketchybar --set "$NAME" drawing=off
  exit 0
}

state="$("$player" get --json title artist playbackRate 2>/dev/null)"
title="$(printf '%s' "$state" | jq -r '.title // empty' 2>/dev/null)"
artist="$(printf '%s' "$state" | jq -r '.artist // empty' 2>/dev/null)"
rate="$(printf '%s' "$state" | jq -r '.playbackRate // 0' 2>/dev/null)"

if [ -z "$title" ] || [ "$title" = "null" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

if [ -n "$artist" ] && [ "$artist" != "null" ]; then
  label="$artist — $title"
else
  label="$title"
fi

icon="󰐊"
color="$MAUVE"
if awk -v rate="$rate" 'BEGIN { exit !(rate > 0) }'; then
  icon="󰏤"
  color="$GREEN"
fi

sketchybar --animate sin 6 \
  --set "$NAME" drawing=on icon="$icon" icon.color="$color" \
    background.border_color="$color" label="$label"

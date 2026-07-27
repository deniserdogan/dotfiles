#!/usr/bin/env sh

. "$CONFIG_DIR/colors.sh"

volume="$INFO"
if [ "$SENDER" != "volume_change" ] || [ -z "$volume" ]; then
  volume="$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)"
fi

case "$volume" in
  ''|*[!0-9]*) exit 0 ;;
esac

if [ "$volume" -eq 0 ]; then
  icon="󰝟"
  color="$MUTED"
elif [ "$volume" -lt 35 ]; then
  icon="󰕿"
  color="$BLUE"
elif [ "$volume" -lt 70 ]; then
  icon="󰖀"
  color="$BLUE"
else
  icon="󰕾"
  color="$BLUE"
fi

sketchybar --set "$NAME" icon="$icon" icon.color="$color" label="${volume}%"

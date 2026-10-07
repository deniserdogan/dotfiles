#!/usr/bin/env sh

case "$PERCENTAGE" in
  ''|*[!0-9]*) exit 0 ;;
esac

osascript -e "set volume output volume $PERCENTAGE" >/dev/null 2>&1
sketchybar --trigger volume_change INFO="$PERCENTAGE"

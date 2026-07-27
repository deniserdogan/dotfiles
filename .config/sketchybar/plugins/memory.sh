#!/usr/bin/env sh

. "$CONFIG_DIR/colors.sh"

free="$(memory_pressure -Q 2>/dev/null | awk '/System-wide memory free percentage/ { gsub("%", "", $5); print $5 }')"
case "$free" in
  ''|*[!0-9]*) exit 0 ;;
esac

used=$((100 - free))
color="$YELLOW"
[ "$used" -ge 75 ] && color="$PEACH"
[ "$used" -ge 90 ] && color="$RED"

sketchybar --set "$NAME" label="${used}%" icon.color="$color"

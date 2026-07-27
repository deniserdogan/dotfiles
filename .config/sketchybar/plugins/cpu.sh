#!/usr/bin/env sh

. "$CONFIG_DIR/colors.sh"

# Show current normalized utilization. Load average measures runnable work over
# time, so brief process bursts during a theme switch could incorrectly pin the
# old display at 100% long after the transition had finished.
cores="$(/usr/sbin/sysctl -n hw.logicalcpu 2>/dev/null)"
[ -n "$cores" ] || exit 0

cpu="$(
  /bin/ps -A -o %cpu= 2>/dev/null |
    /usr/bin/awk -v cores="$cores" '{
      total += $1
    } END {
      value = total / cores
      if (value < 0) value = 0
  if (value > 100) value = 100
  printf "%.0f", value
    }'
)"
[ -n "$cpu" ] || exit 0

level="$(/usr/bin/awk -v value="$cpu" 'BEGIN { printf "%.2f", value / 100 }')"
color="$GREEN"
[ "$cpu" -ge 55 ] && color="$YELLOW"
[ "$cpu" -ge 80 ] && color="$RED"

sketchybar --push "$NAME" "$level" \
  --set "$NAME" label="${cpu}%" icon.color="$color" graph.color="$color"

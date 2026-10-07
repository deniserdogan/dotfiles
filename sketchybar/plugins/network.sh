#!/usr/bin/env sh

. "$CONFIG_DIR/colors.sh"

interface="$(route -n get default 2>/dev/null | awk '/interface:/ { print $2; exit }')"
if [ -z "$interface" ]; then
  sketchybar --set "$NAME" icon="󰖪" icon.color="$MUTED" label="offline"
  exit 0
fi

counters="$(netstat -ibn 2>/dev/null | awk -v iface="$interface" '
  $1 == iface && $7 ~ /^[0-9]+$/ && $10 ~ /^[0-9]+$/ {
    if ($7 > input) input=$7
    if ($10 > output) output=$10
  }
  END { printf "%.0f %.0f", input, output }
')"
set -- $counters
rx="${1:-0}"
tx="${2:-0}"

state_file="/tmp/sketchybar_network_${interface}"
now="$(date +%s)"
old_rx="$rx"
old_tx="$tx"
old_time="$now"

if [ -r "$state_file" ]; then
  read -r old_rx old_tx old_time < "$state_file"
fi
printf '%s %s %s\n' "$rx" "$tx" "$now" > "$state_file"

elapsed=$((now - old_time))
[ "$elapsed" -gt 0 ] || elapsed=1
down=$(((rx - old_rx) / elapsed))
up=$(((tx - old_tx) / elapsed))
[ "$down" -ge 0 ] || down=0
[ "$up" -ge 0 ] || up=0

format_rate() {
  awk -v bytes="$1" 'BEGIN {
    if (bytes >= 1048576) printf "%.1fM", bytes / 1048576
    else if (bytes >= 1024) printf "%.0fK", bytes / 1024
    else printf "%dB", bytes
  }'
}

sketchybar --set "$NAME" \
  icon="󰖩" \
  icon.color="$TEAL" \
  label="↓$(format_rate "$down")  ↑$(format_rate "$up")"

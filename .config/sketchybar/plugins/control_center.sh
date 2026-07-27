#!/usr/bin/env sh

. "$CONFIG_DIR/colors.sh"

host_stats="$(hostinfo 2>/dev/null)"
load="$(printf '%s' "$host_stats" | awk '/Load average:/ { gsub(",", "", $3); print $3; exit }')"
cores="$(printf '%s' "$host_stats" | awk '/processors are logically available/ { print $1; exit }')"
cpu="--"
if [ -n "$load" ] && [ -n "$cores" ]; then
  cpu="$(awk -v load="$load" -v cores="$cores" 'BEGIN {
    value = load / cores * 100
    if (value > 100) value = 100
    printf "%.0f%%", value
  }')"
fi

free="$(memory_pressure -Q 2>/dev/null | awk '/System-wide memory free percentage/ { gsub("%", "", $5); print $5 }')"
memory="--"
case "$free" in
  ''|*[!0-9]*) ;;
  *) memory="$((100 - free))%" ;;
esac

disk="$(df -H / 2>/dev/null | awk 'NR == 2 { print $5 " used · " $4 " free" }')"
[ -n "$disk" ] || disk="--"

display_info="$(yabai -m query --displays 2>/dev/null)"
display_count="$(printf '%s' "$display_info" | jq -r 'length // 0' 2>/dev/null)"
active_display="$(
  printf '%s' "$display_info" |
    jq -r '
      map(select(."has-focus" == true))[0]
      | if . == null then empty
        else .index
        end
    ' 2>/dev/null
)"
active_resolution="$(
  printf '%s' "$display_info" |
    jq -r '
      map(select(."has-focus" == true))[0].frame
      | if . == null then empty
        else "\(.w | floor)×\(.h | floor)"
        end
    ' 2>/dev/null
)"
if [ -n "$active_resolution" ]; then
  display="Display $active_display/$display_count · $active_resolution"
else
  display="$display_count connected"
fi

interface="$(netstat -rn -f inet 2>/dev/null | awk '$1 == "default" { print $NF; exit }')"
ip=""
[ -n "$interface" ] && ip="$(ipconfig getifaddr "$interface" 2>/dev/null)"
if [ -n "$ip" ]; then
  network="$interface · $ip"
else
  network="Offline"
fi

vpn_interface="$(netstat -rn -f inet 2>/dev/null | awk '$1 == "0/1" && $NF ~ /^utun/ { print $NF; exit }')"
if [ -n "$vpn_interface" ] && netstat -rn -f inet 2>/dev/null | awk -v iface="$vpn_interface" '$1 == "128.0/1" && $NF == iface { found=1 } END { exit !found }'; then
  vpn="Connected · $vpn_interface"
  vpn_color="$GREEN"
else
  vpn="Disconnected"
  vpn_color="$MUTED"
fi

battery_raw="$(system_profiler SPPowerDataType 2>/dev/null)"
health="$(printf '%s' "$battery_raw" | awk -F': ' '/Condition:/ { print $2; exit }')"
capacity="$(printf '%s' "$battery_raw" | awk -F': ' '/Maximum Capacity:/ { print $2; exit }')"
cycles="$(printf '%s' "$battery_raw" | awk -F': ' '/Cycle Count:/ { print $2; exit }')"
battery="${capacity:---}"
[ -n "$health" ] && battery="$battery · $health"
[ -n "$cycles" ] && battery="$battery · $cycles cycles"

volume="$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)"
case "$volume" in
  ''|*[!0-9]*) volume=0 ;;
esac

sketchybar --set cc.cpu label="CPU  $cpu" \
  --set cc.memory label="Memory  $memory" \
  --set cc.disk label="Disk  $disk" \
  --set cc.display label="Displays  $display" \
  --set cc.network label="Network  $network" \
  --set cc.vpn label="AmneziaVPN  $vpn" icon.color="$vpn_color" \
  --set cc.battery label="Battery  $battery" \
  --set cc.volume slider.percentage="$volume" \
  --set apple popup.drawing=toggle

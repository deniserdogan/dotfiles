#!/usr/bin/env sh

. "$CONFIG_DIR/colors.sh"

popup_clear="$(printf '%s' "$BAR_COLOR" | sed 's/^0x../0x00/')"

close_popup() {
  sketchybar --animate sin 5 \
    --set apple \
      popup.y_offset=2 \
      popup.background.color="$popup_clear" \
      background.border_color="$ITEM_BORDER" \
    --set "/cc\\..*/" \
      icon.y_offset=0 \
      label.y_offset=0

  /bin/sleep 0.09

  sketchybar \
    --set apple \
      popup.drawing=off \
      popup.y_offset=7 \
      popup.background.color="$BAR_COLOR" \
    --set "/cc\\..*/" \
      icon.y_offset=0 \
      label.y_offset=0
}

if [ "${1:-}" = "close" ]; then
  close_popup
  exit 0
fi

popup_state="$(
  sketchybar --query apple 2>/dev/null |
    jq -r '.popup.drawing // "off"' 2>/dev/null
)"
if [ "$popup_state" = "on" ]; then
  close_popup
  exit 0
fi

# Open immediately with the last known contents; refresh telemetry afterward.
# Keep text baselines fixed rather than moving every row independently.
sketchybar --set apple popup.y_offset=3 \
  popup.background.color="$popup_clear" popup.drawing=on
sketchybar --animate sin 6 --set apple popup.y_offset=7 \
  popup.background.color="$BAR_COLOR" background.border_color="$MAUVE"

computer_name="$(scutil --get ComputerName 2>/dev/null)"
[ -n "$computer_name" ] || computer_name="$(hostname -s 2>/dev/null)"
[ -n "$computer_name" ] || computer_name="This Mac"

os_version="$(sw_vers -productVersion 2>/dev/null)"
[ -n "$os_version" ] || os_version="--"

booted="$(who -b 2>/dev/null | awk '{ print $3 " " $4 " · " $5; exit }')"
if [ -n "$booted" ]; then
  system="macOS $os_version · Booted $booted"
else
  system="macOS $os_version"
fi

disk_row="$(df -H / 2>/dev/null | awk 'NR == 2 { print $2 "\t" $4; exit }')"
disk_total="$(printf '%s' "$disk_row" | awk -F '\t' '{ print $1 }')"
disk_free="$(printf '%s' "$disk_row" | awk -F '\t' '{ print $2 }')"
if [ -n "$disk_total" ] && [ -n "$disk_free" ]; then
  storage="$disk_free free of $disk_total"
else
  storage="Unavailable"
fi

display_info="$(yabai -m query --displays 2>/dev/null)"
display_count="$(printf '%s' "$display_info" | jq -r 'length // 0' 2>/dev/null)"
active_resolution="$(
  printf '%s' "$display_info" |
    jq -r '
      map(select(."has-focus" == true))[0].frame
      | if . == null then empty
        else "\(.w | floor)×\(.h | floor)"
        end
    ' 2>/dev/null
)"
case "$display_count" in
  1) display="$active_resolution · 1 display" ;;
  ''|0) display="Unavailable" ;;
  *) display="$active_resolution · $display_count displays" ;;
esac

vpn_interface="$(
  netstat -rn -f inet 2>/dev/null |
    awk '$1 == "0/1" && $NF ~ /^utun/ { print $NF; exit }'
)"
if [ -n "$vpn_interface" ] &&
  netstat -rn -f inet 2>/dev/null |
    awk -v iface="$vpn_interface" '
      $1 == "128.0/1" && $NF == iface { found=1 }
      END { exit !found }
    '; then
  vpn="Connected · $vpn_interface"
  vpn_color="$GREEN"
else
  vpn="Disconnected"
  vpn_color="$MUTED"
fi

if [ "$THEME_MODE" = "dark" ]; then
  appearance="Switch to Light Appearance"
else
  appearance="Switch to Dark Appearance"
fi

# Refresh the open panel without restarting its entrance animation.
sketchybar \
  --set cc.header label="$computer_name" \
  --set cc.system label="$system" \
  --set cc.storage label="$storage" \
  --set cc.display label="$display" \
  --set cc.vpn label="AmneziaVPN  $vpn" icon.color="$vpn_color" \
  --set cc.appearance label="$appearance"

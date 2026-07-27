#!/usr/bin/env sh

token="$(date +%s)-$$"
token_file="/tmp/yabai_sketchybar_topology"
printf '%s\n' "$token" > "$token_file"

(
  sleep 0.45
  current_token="$(sed -n '1p' "$token_file" 2>/dev/null)"
  [ "$current_token" = "$token" ] || exit 0

  /bin/sh "$HOME/.config/yabai/scripts/sync_space_roles.sh"
  sketchybar --reload
) >/dev/null 2>&1 &

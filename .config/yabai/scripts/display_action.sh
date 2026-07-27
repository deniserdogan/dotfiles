#!/usr/bin/env sh

action="$1"
direction="$2"
refresh="$HOME/.config/yabai/scripts/refresh_space_topology.sh"
sync_roles="$HOME/.config/yabai/scripts/sync_space_roles.sh"

/bin/sh "$sync_roles"

displays="$(yabai -m query --displays 2>/dev/null)" || exit 1
display_count="$(printf '%s' "$displays" | jq 'length')"
[ "$display_count" -gt 1 ] || exit 0

if [ "$action" = "focus" ]; then
  if [ "$direction" = "cycle" ]; then
    yabai -m display --focus next 2>/dev/null ||
      yabai -m display --focus first 2>/dev/null
  else
    yabai -m display --focus "$direction" 2>/dev/null
  fi
  exit $?
fi

current_space="$(yabai -m query --spaces --space 2>/dev/null)" || exit 1
role="$(printf '%s' "$current_space" | jq -r '.label // empty')"
current_display="$(printf '%s' "$current_space" | jq -r '.display')"
case "$role" in
  slot.[0-9]*) ;;
  *) exit 1 ;;
esac

case "$action" in
  cycle)
    target_display="$(
      printf '%s' "$displays" | jq -r --argjson current "$current_display" '
        [.[].index] as $indices
        | ($indices | index($current)) as $position
        | if $position == null then empty
          else $indices[(($position + 1) % ($indices | length))]
          end
      '
    )"
    ;;
  move)
    case "$direction" in
      west|south|north|east) ;;
      *) exit 2 ;;
    esac
    target_display="$(
      yabai -m query --displays --display "$direction" 2>/dev/null |
        jq -r '.index // empty'
    )"
    ;;
  builtin)
    builtin_id="$(
      system_profiler SPDisplaysDataType -json 2>/dev/null |
        jq -r '
          ..
          | objects
          | select(.spdisplays_connection_type? == "spdisplays_internal")
          | ._spdisplays_displayID // empty
        ' |
        head -1
    )"
    target_display="$(
      printf '%s' "$displays" |
        jq -r --arg id "$builtin_id" '
          .[] | select((.id | tostring) == $id) | .index
        ' |
        head -1
    )"
    ;;
  *)
    exit 2
    ;;
esac

[ -n "$target_display" ] || exit 1
[ "$target_display" != "$current_display" ] || exit 0

yabai -m space "$role" --display "$target_display" || exit 1

attempt=0
while [ "$attempt" -lt 12 ]; do
  moved_display="$(
    yabai -m query --spaces --space "$role" 2>/dev/null |
      jq -r '.display // empty'
  )"
  [ "$moved_display" = "$target_display" ] && break
  attempt=$((attempt + 1))
  sleep 0.05
done

yabai -m space --focus "$role" >/dev/null 2>&1
sketchybar --trigger yabai_stack_changed
/bin/sh "$refresh"

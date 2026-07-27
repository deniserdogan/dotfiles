#!/usr/bin/env sh

slot="$1"

case "$slot" in
  ''|*[!0-9]*) exit 2 ;;
esac
[ "$slot" -gt 0 ] || exit 2

/bin/sh "$HOME/.config/yabai/scripts/sync_space_roles.sh"

role="slot.$slot"
target="$(yabai -m query --spaces --space "$role" 2>/dev/null)" || exit 1
current="$(yabai -m query --spaces --space 2>/dev/null)" || exit 1

current_role="$(printf '%s' "$current" | jq -r '.label // empty')"
current_key="$(
  printf '%s' "$current" |
    jq -r 'if .uuid != "" then .uuid else "id:\(.id)" end'
)"
history_file="/tmp/yabai_previous_semantic_space"

if [ "$current_role" = "$role" ]; then
  previous_key="$(sed -n '1p' "$history_file" 2>/dev/null)"
  if [ -n "$previous_key" ]; then
    previous_index="$(
      yabai -m query --spaces 2>/dev/null |
        jq -r --arg key "$previous_key" '
          .[]
          | select(
              (if .uuid != "" then .uuid else "id:\(.id)" end) == $key
            )
          | .index
        ' |
        head -1
    )"
    [ -n "$previous_index" ] && yabai -m space --focus "$previous_index" && exit 0
  fi
  yabai -m space --focus recent
  exit $?
fi

printf '%s\n' "$current_key" > "$history_file"
yabai -m space --focus "$role"

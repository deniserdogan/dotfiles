#!/usr/bin/env sh

STATE_FILE="$HOME/.config/yabai/space_roles.tsv"
current="$(yabai -m query --spaces --space 2>/dev/null)" || exit 1
key="$(
  printf '%s' "$current" |
    jq -r 'if .uuid != "" then .uuid else "id:\(.id)" end'
)"

yabai -m space --destroy || exit 1

temporary="$(mktemp /tmp/yabai_space_roles.XXXXXX)" || exit 1
awk -v key="$key" '$1 != key' "$STATE_FILE" > "$temporary"
mv "$temporary" "$STATE_FILE"

/bin/sh "$HOME/.config/yabai/scripts/refresh_space_topology.sh"

#!/usr/bin/env sh

slot="$1"
case "$slot" in
  1|2|3|4|5|6|7|8|9) ;;
  *) exit 2 ;;
esac

/bin/sh "$HOME/.config/yabai/scripts/sync_space_roles.sh"
role="slot.$slot"

yabai -m query --spaces --space "$role" >/dev/null 2>&1 || exit 1
yabai -m window --space "$role"

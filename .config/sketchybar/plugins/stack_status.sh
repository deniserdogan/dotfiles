#!/usr/bin/env sh

spaces="$(
  yabai -m query --spaces 2>/dev/null |
    jq -r '
      .[]
      | select(."is-native-fullscreen" == false)
      | [.index, .label]
      | @tsv
    '
)"

while IFS="$(printf '\t')" read -r space_index space_role; do
  [ -n "$space_index" ] || continue
  slot="${space_role#slot.}"
  case "$space_role" in
    slot.[0-9]*) ;;
    *) slot="$space_index" ;;
  esac

  stack_count="$(yabai -m query --windows --space "$space_index" 2>/dev/null | jq -r 'map(."stack-index") | max // 0' 2>/dev/null)"
  case "$stack_count" in
    ''|*[!0-9]*) stack_count=0 ;;
  esac

  if [ "$stack_count" -gt 1 ]; then
    # Generate the UTF-8 middle dot from bytes so launchd's locale cannot
    # corrupt the compact “space·stack” badge.
    separator="$(printf '\302\267')"
    icon="${slot}${separator}${stack_count}"
  else
    icon="$slot"
  fi

  sketchybar --set "space.$space_index" icon="$icon"
done <<EOF
$spaces
EOF

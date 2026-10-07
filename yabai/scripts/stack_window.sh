#!/usr/bin/env sh

cycle_stack() {
  direction="$1"
  current="$(yabai -m query --windows --window 2>/dev/null)" || exit 1
  space="$(printf '%s' "$current" | jq -r '.space // empty')"
  stack_index="$(printf '%s' "$current" | jq -r '."stack-index" // 0')"

  [ -n "$space" ] && [ "$stack_index" -gt 0 ] || exit 0

  windows="$(yabai -m query --windows --space "$space" 2>/dev/null)" || exit 1
  target="$(
    printf '%s' "$windows" | jq -r \
      --argjson current "$current" \
      --arg direction "$direction" '
        [
          .[]
          | select(
              ."stack-index" > 0
              and .frame.x == $current.frame.x
              and .frame.y == $current.frame.y
              and .frame.w == $current.frame.w
              and .frame.h == $current.frame.h
            )
        ]
        | sort_by(."stack-index") as $stack
        | ($stack | length) as $length
        | ($stack | map(.id) | index($current.id)) as $position
        | if $length < 2 or $position == null then
            empty
          elif $direction == "next" then
            $stack[(($position + 1) % $length)].id
          else
            $stack[(($position + $length - 1) % $length)].id
          end
      '
  )"

  [ -n "$target" ] && yabai -m window --focus "$target"
}

toggle_stack() {
  current="$(yabai -m query --windows --window 2>/dev/null)" || exit 1
  stack_index="$(printf '%s' "$current" | jq -r '."stack-index" // 0')"

  if [ "$stack_index" -le 0 ]; then
    # Either side of the BSP tree may be absent at an edge.
    yabai -m window --stack next 2>/dev/null ||
      yabai -m window --stack prev
    return
  fi

  # Yabai rejects warping against a peer in the same stack. Re-entering
  # management immediately is direction-independent and inserts the focused
  # window as its own BSP node; both commands complete in one shortcut press.
  yabai -m window --toggle float &&
    yabai -m window --toggle float
}

case "$1" in
  create|toggle) toggle_stack ;;
  previous) cycle_stack previous ;;
  next) cycle_stack next ;;
  *) exit 2 ;;
esac

sketchybar --trigger yabai_stack_changed

#!/usr/bin/env sh

direction="$1"

case "$direction" in
  west|south|north|east) ;;
  *) exit 2 ;;
esac

focused="$(yabai -m query --windows --window 2>/dev/null)"
was_zoomed="$(
  printf '%s' "$focused" |
    jq -r '."has-fullscreen-zoom" // false' 2>/dev/null
)"

# A zoomed node has no useful directional geometry. Resolve its sibling by
# tree order and transfer fullscreen zoom directly, without revealing tiles.
if [ "$was_zoomed" = "true" ]; then
  case "$direction" in
    west|north)
      selector="prev"
      fallback="last"
      ;;
    east|south)
      selector="next"
      fallback="first"
      ;;
  esac

  target_info="$(yabai -m query --windows --window "$selector" 2>/dev/null)"
  target="$(printf '%s' "$target_info" | jq -r '.id // empty' 2>/dev/null)"
  if [ -z "$target" ]; then
    target_info="$(yabai -m query --windows --window "$fallback" 2>/dev/null)"
    target="$(printf '%s' "$target_info" | jq -r '.id // empty' 2>/dev/null)"
  fi

  current="$(printf '%s' "$focused" | jq -r '.id // empty' 2>/dev/null)"
  if [ -n "$target" ] && [ "$target" != "$current" ]; then
    target_zoomed="$(
      printf '%s' "$target_info" |
        jq -r '."has-fullscreen-zoom" // false' 2>/dev/null
    )"
    if [ "$target_zoomed" = "true" ]; then
      yabai -m window --focus "$target" 2>/dev/null
    else
      yabai -m window "$target" --toggle zoom-fullscreen 2>/dev/null &&
        yabai -m window --focus "$target" 2>/dev/null
    fi
    exit $?
  fi
  exit 1
fi

# Prefer normal directional focus. If there is no window in that direction,
# select the window at the opposite edge of the current space.
if yabai -m window --focus "$direction" 2>/dev/null; then
  exit 0
fi

if ! windows="$(yabai -m query --windows --space 2>/dev/null)"; then
  exit 1
fi

case "$direction" in
  west)
    edge='max_by(.frame.x + .frame.w)'
    ;;
  east)
    edge='min_by(.frame.x)'
    ;;
  north)
    edge='max_by(.frame.y + .frame.h)'
    ;;
  south)
    edge='min_by(.frame.y)'
    ;;
esac

target="$(
  printf '%s' "$windows" |
    jq -r "
      [
        .[]
        | select(
            (.\"is-minimized\" // false) == false
            and (.\"is-hidden\" // false) == false
            and (.\"has-focus\" // false) == false
          )
      ]
      | $edge
      | .id // empty
    "
)"

if [ -n "$target" ] && yabai -m window --focus "$target"; then
  exit 0
fi

exit 1

#!/usr/bin/env sh

. "$CONFIG_DIR/colors.sh"

user_id="${UID:-$(/usr/bin/id -u)}"
hover_file="/tmp/sketchybar_hovered_$user_id"
hover_lock="/tmp/sketchybar_hover_lock_$user_id"

acquire_hover_lock() {
  attempts=0
  while ! mkdir "$hover_lock" 2>/dev/null; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 50 ]; then
      rmdir "$hover_lock" 2>/dev/null
      attempts=0
    fi
    sleep 0.01
  done
}

release_hover_lock() {
  rmdir "$hover_lock" 2>/dev/null
}

reset_item() {
  target="$1"
  [ -n "$target" ] || return 0
  sketchybar --query "$target" >/dev/null 2>&1 || return 0

  background="$ITEM_BG"
  border="$ITEM_BORDER"
  border_width=1

  case "$target" in
    apple|front_app|clock)
      background="$ITEM_BG_STRONG"
      ;;
    media)
      background="$ITEM_BG_STRONG"
      border="$(
        sketchybar --query "$target" 2>/dev/null |
          jq -r '.icon.color // empty' 2>/dev/null
      )"
      [ -n "$border" ] || border="$MAUVE"
      ;;
    cc.header|cc.settings|cc.appearance|cc.sleep)
      background="$ITEM_BG_STRONG"
      border_width=0
      ;;
    cc.system|cc.storage|cc.display|cc.vpn)
      border_width=0
      ;;
    space.*)
      index="${target#space.}"
      visible="$(
        yabai -m query --spaces 2>/dev/null |
          jq -r --argjson index "$index" '
            any(.[]; .id == $index and ."is-visible" == true)
          ' 2>/dev/null
      )"
      if [ "$visible" = "true" ]; then
        background="$BLUE"
        border="$BLUE"
      fi
      ;;
  esac

  sketchybar --animate tanh 11 \
    --set "$target" \
      background.color="$background" \
      background.border_color="$border" \
      background.border_width="$border_width" \
      background.height=28 \
      background.shadow.drawing=off \
      icon.y_offset=0 \
      label.y_offset=0
  sketchybar --set "$target" background.shadow.drawing=off
}

hover_entered() {
  previous="$(sed -n '1p' "$hover_file" 2>/dev/null)"
  if [ -n "$previous" ] && [ "$previous" != "$NAME" ]; then
    reset_item "$previous"
  fi
  printf '%s\n' "$NAME" > "$hover_file"

  accent="$(
    sketchybar --query "$NAME" 2>/dev/null |
      jq -r '.icon.color // empty' 2>/dev/null
  )"
  [ -n "$accent" ] || accent="$BLUE"

  case "$NAME" in
    space.*) accent="$BLUE" ;;
  esac

  sketchybar --animate tanh 9 \
    --set "$NAME" \
      background.color="$ITEM_BG_STRONG" \
      background.border_color="$accent" \
      background.border_width=2 \
      background.height=31 \
      icon.y_offset=2 \
      label.y_offset=1
}

hover_exited() {
  reset_item "$NAME"

  current="$(sed -n '1p' "$hover_file" 2>/dev/null)"
  if [ "$current" = "$NAME" ]; then
    rm -f "$hover_file"
  fi
}

hover_global_exited() {
  previous="$(sed -n '1p' "$hover_file" 2>/dev/null)"
  reset_item "$previous"
  rm -f "$hover_file"
}

run_update() {
  case "$NAME" in
    space.*) exec "$CONFIG_DIR/plugins/space.sh" ;;
    front_app) exec "$CONFIG_DIR/plugins/front_app.sh" ;;
    media) exec "$CONFIG_DIR/plugins/media.sh" ;;
    cpu) exec "$CONFIG_DIR/plugins/cpu.sh" ;;
    memory) exec "$CONFIG_DIR/plugins/memory.sh" ;;
    network) exec "$CONFIG_DIR/plugins/network.sh" ;;
    volume) exec "$CONFIG_DIR/plugins/volume.sh" ;;
    battery) exec "$CONFIG_DIR/plugins/battery.sh" ;;
    clock) exec "$CONFIG_DIR/plugins/clock.sh" ;;
  esac
}

case "$SENDER" in
  mouse.entered)
    acquire_hover_lock
    trap release_hover_lock EXIT HUP INT TERM
    hover_entered
    ;;
  mouse.exited)
    acquire_hover_lock
    trap release_hover_lock EXIT HUP INT TERM
    hover_exited
    ;;
  mouse.exited.global)
    acquire_hover_lock
    trap release_hover_lock EXIT HUP INT TERM
    hover_global_exited
    ;;
  *) run_update ;;
esac

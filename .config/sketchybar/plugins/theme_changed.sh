#!/usr/bin/env sh

# Recolor the live bar in place. Reloading here would recursively fire this
# appearance event, so every visible property is updated directly instead.
user_id="${UID:-$(/usr/bin/id -u)}"
PENDING_FILE="/tmp/sketchybar_theme_pending_$user_id"
if [ -z "${THEME_MODE:-}" ] && [ -r "$PENDING_FILE" ]; then
  pending_theme="$(/bin/cat "$PENDING_FILE")"
  if [ "$pending_theme" = "dark" ] || [ "$pending_theme" = "light" ]; then
    THEME_MODE="$pending_theme"
    export THEME_MODE
  fi
fi

# A macOS appearance event is the authority when no hotkey transition supplied
# an explicit target. Set it before loading colors so stale widget state cannot
# mask a theme change made from System Settings.
if [ -z "${THEME_MODE:-}" ]; then
  if [ "$(/usr/bin/defaults read -g AppleInterfaceStyle 2>/dev/null)" = "Dark" ]; then
    THEME_MODE=dark
  else
    THEME_MODE=light
  fi
  export THEME_MODE
fi

. "$CONFIG_DIR/colors.sh"

STATE_FILE="/tmp/sketchybar_theme_mode_$user_id"
if [ "${FORCE_THEME_UPDATE:-0}" != "1" ] &&
  [ -r "$STATE_FILE" ] &&
  [ "$(/bin/cat "$STATE_FILE")" = "$THEME_MODE" ]; then
  exit 0
fi
printf "%s\n" "$THEME_MODE" >"$STATE_FILE"

SKETCHYBAR=/opt/homebrew/bin/sketchybar
YABAI=/opt/homebrew/bin/yabai
JQ=/opt/homebrew/bin/jq
GHOSTTY_THEME_FILE="$HOME/.config/ghostty/theme-mode"

if [ "$THEME_MODE" = "dark" ]; then
  GHOSTTY_THEME=Nordfox
else
  GHOSTTY_THEME="Xcode Light"
fi
/usr/bin/printf 'theme = %s\n' "$GHOSTTY_THEME" >"$GHOSTTY_THEME_FILE"
/usr/bin/pkill -USR2 -x ghostty >/dev/null 2>&1 || true

"$SKETCHYBAR" --default \
  icon.color="$TEXT" \
  label.color="$TEXT" \
  background.color="$ITEM_BG" \
  background.border_color="$ITEM_BORDER"

# Apply the complete palette in one batch, whether the appearance changed from
# the hotkey or somewhere else in macOS.
set -- \
  --bar \
    color="$BAR_COLOR" \
    border_color="$BAR_BORDER" \
  --set apple \
    icon.color="$MAUVE" \
    background.color="$ITEM_BG_STRONG" \
    background.border_color="$ITEM_BORDER" \
    popup.background.color="$BAR_COLOR" \
    popup.background.border_color="$BAR_BORDER" \
  --set "/cc\\..*/" \
    icon.color="$TEXT" \
    label.color="$TEXT" \
    background.color="$ITEM_BG" \
    background.border_color="$ITEM_BORDER" \
  --set cc.header \
    icon.color="$MAUVE" \
    background.color="$ITEM_BG_STRONG" \
  --set cc.system \
    icon.color="$BLUE" \
    label.color="$SUBTEXT" \
  --set cc.storage \
    icon.color="$PEACH" \
    label.color="$SUBTEXT" \
  --set cc.display \
    icon.color="$TEAL" \
    label.color="$SUBTEXT" \
  --set cc.vpn icon.color="$BLUE" \
  --set cc.actions_label \
    label.color="$MUTED" \
    background.drawing=off \
  --set cc.settings \
    icon.color="$MAUVE" \
    background.color="$ITEM_BG_STRONG" \
  --set cc.appearance \
    icon.color="$BLUE" \
    background.color="$ITEM_BG_STRONG" \
  --set cc.sleep \
    icon.color="$YELLOW" \
    background.color="$ITEM_BG_STRONG" \
  --set front_app \
    icon.color="$TEXT" \
    label.color="$SUBTEXT" \
    background.color="$ITEM_BG_STRONG" \
    background.border_color="$ITEM_BORDER" \
  --set media \
    icon.color="$MAUVE" \
    label.color="$TEXT" \
    background.color="$ITEM_BG_STRONG" \
    background.border_color="$MAUVE" \
  --set cpu \
    icon.color="$GREEN" \
    label.color="$TEXT" \
    background.color="$ITEM_BG" \
    background.border_color="$ITEM_BORDER" \
    graph.color="$GREEN" \
    graph.fill_color="$GREEN_FILL" \
  --set memory \
    icon.color="$YELLOW" \
    label.color="$TEXT" \
    background.color="$ITEM_BG" \
    background.border_color="$ITEM_BORDER" \
  --set network \
    icon.color="$TEAL" \
    label.color="$TEXT" \
    background.color="$ITEM_BG" \
    background.border_color="$ITEM_BORDER" \
  --set volume \
    icon.color="$BLUE" \
    label.color="$TEXT" \
    background.color="$ITEM_BG" \
    background.border_color="$ITEM_BORDER" \
  --set battery \
    icon.color="$GREEN" \
    label.color="$TEXT" \
    background.color="$ITEM_BG" \
    background.border_color="$ITEM_BORDER" \
  --set clock \
    icon.color="$MAUVE" \
    label.color="$TEXT" \
    background.color="$ITEM_BG_STRONG" \
    background.border_color="$ITEM_BORDER"

# Preserve every currently visible Space (one per display) as selected while
# adding it to the same animation batch as the rest of the bar.
space_rows="$(
  "$YABAI" -m query --spaces 2>/dev/null |
    "$JQ" -r '.[] | select(."is-native-fullscreen" == false) | [.id, ."is-visible"] | @tsv' 2>/dev/null
)"
while IFS="$(printf '\t')" read -r index visible; do
  [ -n "$index" ] || continue
  if [ "$visible" = "true" ]; then
    set -- "$@" \
      --set "space.$index" \
        background.color="$BLUE" \
        background.border_color="$BLUE" \
        icon.color="$ACTIVE_TEXT" \
        label.color="$ACTIVE_TEXT"
  else
    set -- "$@" \
      --set "space.$index" \
        background.color="$ITEM_BG" \
        background.border_color="$ITEM_BORDER" \
        icon.color="$TEXT" \
        label.color="$SUBTEXT"
  fi
done <<EOF
$space_rows
EOF

"$SKETCHYBAR" "$@"
/bin/sh "$CONFIG_DIR/plugins/native_palette.sh"

if [ "${SKIP_NVIM_SYNC:-0}" != "1" ]; then
  # Running Neovim instances listen for SIGUSR1 and select the matching theme.
  # Do this last so process discovery cannot hold up the visible bar update.
  /usr/bin/pkill -USR1 -x nvim >/dev/null 2>&1 || true
fi

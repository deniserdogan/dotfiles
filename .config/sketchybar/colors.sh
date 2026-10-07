#!/usr/bin/env sh

requested_theme="${THEME_MODE:-}"
user_id="${UID:-$(/usr/bin/id -u)}"
pending_file="/tmp/sketchybar_theme_pending_$user_id"
state_file="/tmp/sketchybar_theme_mode_$user_id"

# During a switch, every plugin must use the same requested palette even while
# macOS's defaults database still reports the previous appearance.
if [ -z "$requested_theme" ] && [ -r "$pending_file" ]; then
  pending_theme="$(/bin/cat "$pending_file" 2>/dev/null)"
  if [ "$pending_theme" = "dark" ] || [ "$pending_theme" = "light" ]; then
    requested_theme="$pending_theme"
  fi
fi

# Between theme events, the last committed bar state is authoritative. This
# prevents Space and widget updates from repainting with a lagging system value.
if [ -z "$requested_theme" ] && [ -r "$state_file" ]; then
  committed_theme="$(/bin/cat "$state_file" 2>/dev/null)"
  if [ "$committed_theme" = "dark" ] || [ "$committed_theme" = "light" ]; then
    requested_theme="$committed_theme"
  fi
fi

if [ "$requested_theme" = "dark" ] ||
  { [ -z "$requested_theme" ] &&
    [ "$(/usr/bin/defaults read -g AppleInterfaceStyle 2>/dev/null)" = "Dark" ]; }; then
  # Nordfox
  THEME_MODE=dark
  BAR_COLOR=0xe62e3440
  BAR_BORDER=0x6653648d
  ITEM_BG=0xb33b4252
  ITEM_BG_STRONG=0xe63e4a5b
  ITEM_BORDER=0x5560728a

  TEXT=0xffcdcecf
  ACTIVE_TEXT=0xff2e3440
  SUBTEXT=0xffd8dee9
  MUTED=0xff60728a
  BLUE=0xff81a1c1
  TEAL=0xff88c0d0
  GREEN=0xffa3be8c
  GREEN_FILL=0x25a3be8c
  YELLOW=0xffebcb8b
  PEACH=0xffd08770
  RED=0xffbf616a
  MAUVE=0xffb48ead
else
  # Xcode Light
  THEME_MODE=light
  BAR_COLOR=0xe6ffffff
  BAR_BORDER=0x668a99a6
  ITEM_BG=0xb3e7f2ff
  ITEM_BG_STRONG=0xe6b4d8fd
  ITEM_BORDER=0x558a99a6

  TEXT=0xff262626
  ACTIVE_TEXT=0xffffffff
  SUBTEXT=0xff4a4a4a
  MUTED=0xff8a99a6
  BLUE=0xff0f68a0
  TEAL=0xff3e8087
  GREEN=0xff23575c
  GREEN_FILL=0x253e8087
  YELLOW=0xff78492a
  PEACH=0xff9c4f20
  RED=0xffd12f1b
  MAUVE=0xffad3da4
fi

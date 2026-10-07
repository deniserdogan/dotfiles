#!/usr/bin/env sh

player="/opt/homebrew/bin/nowplaying-cli"
[ -x "$player" ] || exit 0

case "$BUTTON" in
  right) "$player" next >/dev/null 2>&1 ;;
  other) "$player" previous >/dev/null 2>&1 ;;
  *) "$player" togglePlayPause >/dev/null 2>&1 ;;
esac

sleep 0.15
sketchybar --update

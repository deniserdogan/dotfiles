#!/usr/bin/env sh
# Compatibility entry point; the bar itself opens the native panel over Mach.
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
case "${1:-}" in
  close) action=--close ;;
  themes) action=--themes ;;
  *) action=--toggle ;;
esac
exec "$CONFIG_DIR/helpers/RicePanel.app/Contents/MacOS/RicePanel" "$action"

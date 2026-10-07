#!/usr/bin/env sh
# Use a fresh, single snapshot; event indices may already have been renumbered.
# A busy mutation owns the final repaint, so this never paints intermediate state.
case "${SENDER:-}" in
  forced|system_woke) flag=--force ;;
  *) flag= ;;
esac
exec /bin/sh "$HOME/.config/yabai/scripts/space_controller.sh" --refresh $flag

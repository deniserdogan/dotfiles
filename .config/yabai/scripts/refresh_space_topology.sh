#!/usr/bin/env sh
# Non-blocking: intermediate callbacks are dropped, never queued. The active
# mutation publishes its complete final strip before releasing the same lock.
exec /bin/sh "$HOME/.config/yabai/scripts/space_controller.sh" --refresh "$@"

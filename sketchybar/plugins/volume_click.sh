#!/usr/bin/env sh

if [ "$BUTTON" = "right" ]; then
  open "x-apple.systempreferences:com.apple.Sound-Settings.extension"
else
  osascript -e 'set volume output muted not (output muted of (get volume settings))'
fi

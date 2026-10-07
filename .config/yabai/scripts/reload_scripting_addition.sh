#!/usr/bin/env sh

# Keep the released daemon's code signature/Accessibility grant, while using
# the maintainer's macOS 26.6 fix for the scripting addition only.
fixed_loader="/usr/local/libexec/yabai-native-fix/yabai"
if [ -x "$fixed_loader" ]; then
  exec sudo -n "$fixed_loader" --load-sa
fi
exec sudo -n /opt/homebrew/bin/yabai --load-sa

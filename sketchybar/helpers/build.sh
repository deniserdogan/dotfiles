#!/usr/bin/env sh
set -eu
directory="$(CDPATH= cd "$(dirname "$0")" && pwd)"
staging="$(mktemp -d /private/tmp/rice-build.XXXXXX)"
# Link away from running executables, then replace each inode atomically.
/usr/bin/xcrun clang -O2 -Wall -Wextra -fobjc-arc \
  "$directory/native_motion.m" -framework Foundation \
  -o "$staging/native_motion"
/usr/bin/xcrun clang -O2 -Wall -Wextra -fobjc-arc \
  "$directory/space_controller.m" -framework Foundation \
  -o "$staging/space_controller"
/usr/bin/xcrun clang -O2 -Wall -Wextra -fobjc-arc \
  "$directory/native_theme.m" -framework Foundation \
  -o "$staging/native_theme"
/usr/bin/xcrun clang -O2 -Wall -Wextra -fobjc-arc \
  "$directory/native_panel.m" -framework AppKit -framework QuartzCore -framework IOKit -framework SystemConfiguration -framework ImageIO \
  -o "$staging/RicePanel"
mkdir -p "$directory/RicePanel.app/Contents/MacOS"
cp "$directory/panel-Info.plist" "$directory/RicePanel.app/Contents/Info.plist"
mv "$staging/native_motion" "$directory/native_motion"
mv "$staging/space_controller" "$directory/space_controller"
mv "$staging/native_theme" "$directory/native_theme"
mv "$staging/RicePanel" "$directory/RicePanel.app/Contents/MacOS/RicePanel"
CONFIG_DIR="$(dirname "$directory")" "$directory/native_theme" --export-palettes
rmdir "$staging"

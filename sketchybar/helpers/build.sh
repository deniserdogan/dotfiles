#!/usr/bin/env sh
set -eu
directory="$(CDPATH= cd "$(dirname "$0")" && pwd)"
/usr/bin/xcrun clang -O2 -Wall -Wextra -fobjc-arc \
  "$directory/native_motion.m" -framework Foundation \
  -o "$directory/native_motion"
/usr/bin/xcrun clang -O2 -Wall -Wextra -fobjc-arc \
  "$directory/space_controller.m" -framework Foundation \
  -o "$directory/space_controller"

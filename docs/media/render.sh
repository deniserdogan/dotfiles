#!/bin/sh
# Render documentation only. Does not start services or change the desktop.
set -eu
repo="$(CDPATH= cd "$(dirname "$0")/../.." && pwd)"
staging="$(mktemp -d /private/tmp/rice-docs.XXXXXX)"
trap 'rm -f "$staging/render"; rmdir "$staging"' EXIT
xcrun clang -O2 -Wall -Wextra -fobjc-arc "$repo/docs/media/render.m" \
  -framework AppKit -framework QuartzCore -framework IOKit \
  -framework SystemConfiguration -framework ImageIO -o "$staging/render"
"$staging/render" "$repo" "$repo/screenshots"

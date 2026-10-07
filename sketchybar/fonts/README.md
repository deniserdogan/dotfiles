# Rice App Icons

`rice-app-icons.ttf` is a side-by-side derivative of
[sketchybar-app-font](https://github.com/kvndrsslr/sketchybar-app-font), version
3.0.5, distributed under CC0-1.0 (see `LICENSE`). App names and trademarks
remain owned by their respective owners.

Install this bundled font into `~/Library/Fonts/`. The original upstream font
is not required for normal use and is never modified.

To rebuild, install the original 3.0.5 `sketchybar-app-font.ttf` into
`~/Library/Fonts/`, install Python's `fonttools` package, and run `python3 build.py`
from this directory. The script also regenerates `app_glyphs.sh` from the
upstream font's APPM metadata. Manual overrides live in `plugins/icon_map.sh`;
unknown applications retain a visible generic icon.

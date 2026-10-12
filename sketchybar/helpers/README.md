# Native motion path

`native_motion.m` handles pointer and selected-Space events directly through
SketchyBar's supported `mach_helper` interface. Hover stays on one serial native
event loop: no shell processes, disk locks, JSON parsing, or yabai queries.
Short sine transitions start from the current animated colour; text baselines
and hit targets stay fixed. Non-pointer data events still dispatch the existing
widget plugins. CPU telemetry reads kernel CPU ticks directly.

Build with `sh "$HOME/.config/sketchybar/helpers/build.sh"` (Apple Command Line
Tools required). The bar starts
the helper itself and falls back to shell handlers if startup fails. Reloads
reuse the helper, and it exits when the associated SketchyBar process exits.
Logs are in `/tmp/sketchybar_native_motion_<uid>.log`.

The launcher opens a native AppKit control center. Choose **Personalize your
desktop** for the theme, wallpaper, launcher-logo galleries, and **Terminal**
opacity/font-size sliders. Terminal settings live in the ignored `rice/ghostty.conf`
override, and reload signals are coalesced while dragging. Ghostty's macOS opacity
restart limitation is explained in the panel; sessions are never closed.
Personal images
live in `~/.config/rice/wallpapers/` and `~/.config/rice/logos/`; the app creates
these folders automatically. Folder changes refresh the gallery without
reloading SketchyBar. Wallpaper selection applies to all Spaces and displays.
**Light** and **Dark** assign the two images of a native appearance-aware HEIC;
the gallery opens on the current appearance so new selections update its default.
macOS owns the transition, with no theme-change polling or service restarts.
**Static** uses one image for both appearances. Original artwork is never resized
or overwritten. HEIC encoding runs on a separate queue so the gallery stays live.

`appearance_wallpaper.h` validates the macOS 14+ wallpaper-store structure and
updates only its global desktop entry. The public NSWorkspace setter disables
Show on all Spaces, so it is not used here. Screensavers and dormant per-Space
settings survive, a local backup is made, and only WallpaperAgent is refreshed
when selecting different wallpaper artwork—not when changing themes.
`native_wallpaper --pair DARK_FILENAME LIGHT_FILENAME` applies a private pair;
`--build-pair` only encodes it, and `--inspect FILE` reads its frames and metadata.
Encoding and preservation regressions: `python3 helpers/tests/wallpaper_test.py`
from `sketchybar/` (hardware HEIC encoding needs a logged-in macOS session).

PNG, SVG, and PDF are recommended for logos; transparent artwork works best
with **Use theme color**. **Apple (default)** restores the standard launcher.
Images, cached thumbnails, and preferences under `~/.config/rice/` are ignored
by Git and are never uploaded by the picker. A fresh checkout uses the default
Apple logo; custom artwork is strictly machine-local.

`space_controller.m` owns desktop creation/deletion/focus and the Space strip.
It is a separate compiled process, so desktop work never blocks hover. It uses
one non-blocking BSD lock, yabai's local client protocol, Foundation JSON parsing,
and one Mach message for the complete strip. Pill names use native desktop IDs,
not renumberable indices. Numbers, app glyphs, stack badges and selection are
committed together; only widths animate. Missing numbered desktops are created
only by an explicit keyboard action, never by callbacks or a stale bar click.
Intermediate callbacks are dropped; the mutation performs its own final refresh
before releasing the lock. Empty desktops use a compact outlined desktop icon;
the first app replaces it without changing the pill's width.
The yabai socket framing follows its official 7.1.25 client implementation:
https://github.com/asmvik/yabai/blob/v7.1.25/src/yabai.c

Read-only renderer regressions (no desktop mutation):
`python3 "$HOME/.config/sketchybar/helpers/tests/space_controller_test.py"`.
The test script resolves configs inside its own checkout, not the live setup;
`DOTFILES_CONFIG_DIR` is the controller's explicit config-root override.

`vendor/sketchybar.h` is unmodified from the official
https://github.com/FelixKratz/SketchyBarHelper repository, commit
`73ee34d377f62fc12ddbf519a2bcdb4b7946292a`. Its GPL-3.0 license is in
`vendor/LICENSE`; the helper source here is also GPL-3.0.

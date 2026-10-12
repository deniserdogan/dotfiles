# Documentation visuals

[← Overview](../../README.md)

## Actual desktop

The main README image uses an explicitly supplied
[desktop capture](desktop-source.png). The native renderer adds the same
gradient, typography, spacing, and shadow as the panel showcases. It places the
capture at 1:1 pixel resolution; it does not redraw its code, change its fonts,
retouch its UI, or synthesize applications. Only the outer frame corners are rounded.

This is a Neovim capture, not a browser-and-editor composite. Personal artwork
visible in it is part of the screenshot only; the original wallpaper and logo
files remain private and ignored by Git. The renderer never reads those files.

## Native panels

The panel showcases use the **actual AppKit view classes** from
[`native_panel.m`](../../sketchybar/helpers/native_panel.m). They are rendered
offscreen at 2× resolution and composed with native system typography,
consistent margins, a neutral gradient, and restrained shadows.

These are product showcase renders, not literal screenshots of a user's desktop.
The only documentation substitutions are:

- Fixed, public sample telemetry and a generic device label.
- A static heading instead of the current date.
- An opaque native surface in place of the screen-dependent vibrancy backdrop.
- A specified theme and filter for each view, without applying a system theme.

Control geometry, card layout, labels, SF Symbols, palette colors, and thumbnail
previews come from the application's own implementation. The palette thumbnails
are illustrative; both the gallery and README disclose this.

A [direct window capture](../../screenshots/theme-picker.png) of the running
theme picker is also available for comparison with the composed views.

## Regenerate

On macOS with Apple's Command Line Tools:

```sh
sh docs/media/render.sh
```

The script compiles a temporary documentation renderer and writes:

- `screenshots/overview.png`
- `screenshots/themes-light.png`
- `screenshots/control-center.png`
- `screenshots/desktop.png` (from the supplied `desktop-source.png` capture)

It does not register an IPC service, start an application event loop, show
windows, read live telemetry, apply a theme, or load artwork from the private
library. It leaves the running desktop unchanged. The renderer source is GPL-3.0, like the native
view implementation it includes.

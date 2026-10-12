# Documentation visuals

[← Overview](../../README.md)

The showcase uses the **actual AppKit view classes** from
[`native_panel.m`](../../sketchybar/helpers/native_panel.m). It is rendered
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

It does not register an IPC service, start an application event loop, show
windows, read live telemetry, apply a theme, or load personal artwork. It leaves
the running desktop unchanged. The renderer source is GPL-3.0, like the native
view implementation it includes.

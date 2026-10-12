# Personalize your desktop

[← Overview](../README.md) · [Shortcuts](KEYBINDINGS.md)

Click the top-left launcher, then **Personalize your desktop**. The native
gallery has separate sections for themes, wallpapers, launcher artwork, and
terminal settings.

## Themes

Click a card to apply its palette across SketchyBar, borders, Ghostty, Neovim,
and macOS light/dark appearance. Other applications follow the macOS appearance
where they support it; their individual color palettes are not overridden.

The gallery remembers one light and one dark theme. `Ctrl + Left Option + Cmd + T`
switches between those selections. Changes made through macOS Appearance settings
use the same coordinator; no terminal restart is needed.

**All** groups dark themes first, then light themes, preserving the order within
each group. **Dark** and **Light** filter the gallery without changing appearance.
Each chosen theme is saved immediately for its own appearance, independently
of the other choice, and restored after service reloads or a restart.

| Light · 10 | Dark · 8 |
| --- | --- |
| Catppuccin Latte | Nordfox |
| Rosé Pine Dawn | Tokyo Night |
| Xcode Light | Catppuccin Mocha |
| Dayfox | Gruvbox |
| Dawnfox | Kanagawa |
| Tokyo Night Day | Rosé Pine |
| Kanagawa Lotus | Carbonfox |
| Gruvbox Light | Catppuccin Macchiato |
| GitHub Light | |
| Everforest Light | |

The [catalog](../sketchybar/themes/catalog.json) is the source of truth. Gallery
thumbnails are illustrative palette previews, not screenshots of your applications.
Use arrow keys to browse cards, Return to apply, and Escape to close.

### Terminal settings

The **Terminal** section provides native sliders for Ghostty's background opacity
(0–100%) and font size (8–40 pt, in half-point steps). Values save automatically
to the private `rice/ghostty.conf` override and survive theme changes. Defaults
are 90% opacity and 17 pt. Neovim's transparent background follows the terminal.

Font-size changes reload without closing sessions. Manually zoomed tabs retain
their zoom; `Cmd + 0` resets it. Ghostty on macOS can require a full restart for
opacity changes; the panel never quits it automatically. Native fullscreen
remains opaque. [Ghostty configuration reference](https://ghostty.org/docs/config/reference)

## Wallpapers & launcher artwork

Use **Open folder** in either gallery to add your files:

```text
~/.config/rice/
├── wallpapers/           your downloaded wallpapers
├── logos/                your launcher artwork
├── cache/                generated previews, native wallpaper pairs, backups
├── personalization.json  local wallpaper/logo preferences
├── ghostty.conf          local opacity/font-size overrides
└── theme-selection.json  remembered light/dark themes
```

Folder changes refresh the gallery automatically. Wallpapers apply to all
Spaces and displays, including new desktops and subsequently connected monitors.
macOS's **Show on all Spaces** setting stays enabled, so changes made in System
Settings can also apply everywhere.

Opening the wallpaper gallery automatically targets the current light/dark
appearance. Clicking an image replaces that appearance's remembered default,
without changing the other one. Choose **Light** or **Dark** explicitly to edit
the other appearance's default. The two images become one native, appearance-aware
HEIC in the private cache. macOS handles the switch automatically when appearance
changes, whether from the theme picker, keyboard shortcut, or System Settings.
No desktop cycling, background polling, or service restart occurs on theme changes.
On the first assignment, the same image fills both roles until you choose another.
**Static** applies one image for both appearances; the remembered pair is retained.

All-Spaces application uses the wallpaper store available on macOS 14 and later;
the public desktop-image setter only changes the visible Space and disables the
global setting. A wallpaper selection refreshes only WallpaperAgent, preserves
screensaver and per-Space settings, and saves a local backup in `rice/cache/`.
An unrecognized store format is rejected without modification.

PNG, SVG, and PDF work well for logos. Transparent artwork is best when using
the optional **Use theme color** tint. Choose **Apple (default)** to restore the
standard launcher.

## What stays private

Everything under `rice/` is ignored by Git: images, cached previews, and saved
preferences. The picker reads local files and does not upload them. A fresh
installation uses the Apple logo and receives no personal artwork or wallpapers.

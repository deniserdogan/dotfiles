# Personalize your desktop

[← Overview](../README.md) · [Shortcuts](KEYBINDINGS.md)

Click the top-left launcher, then **Personalize your desktop**. The native
gallery has separate sections for themes, wallpapers, and launcher artwork.

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

Ghostty uses 90% background opacity. Neovim's transparent background follows
the terminal palette.

## Wallpapers & launcher artwork

Use **Open folder** in either gallery to add your files:

```text
~/.config/rice/
├── wallpapers/           your downloaded wallpapers
├── logos/                your launcher artwork
├── cache/                generated previews
├── personalization.json  local wallpaper/logo preferences
└── theme-selection.json  remembered light/dark themes
```

Folder changes refresh the gallery automatically. Wallpaper selection applies
to the current desktop on the selected display(s), not every Space at once.

PNG, SVG, and PDF work well for logos. Transparent artwork is best when using
the optional **Use theme color** tint. Choose **Apple (default)** to restore the
standard launcher.

## What stays private

Everything under `rice/` is ignored by Git: images, cached previews, and saved
preferences. The picker reads local files and does not upload them. A fresh
installation uses the Apple logo and receives no personal artwork or wallpapers.

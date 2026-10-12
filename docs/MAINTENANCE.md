# Maintenance & troubleshooting

[← Overview](../README.md) · [Setup](SETUP.md)

## Update

Run these commands from your checkout:

```sh
git pull --ff-only
./setup.sh --skip-packages
sketchybar --reload
```

If Yabai or skhd configurations changed, also run:

```sh
./setup.sh --skip-packages --start-services
```

After a Yabai upgrade, review scripting-addition compatibility and update any
hash-pinned sudoers rule you installed manually.

## Diagnose

Start with `./setup.sh --doctor`. It checks tools, config links, fonts, and
compiled helpers without changing the desktop.

| Symptom | Check |
| --- | --- |
| Hotkeys do nothing | skhd Accessibility permission, Secure Keyboard Entry, shortcut conflicts |
| Windows do not tile | Yabai Accessibility permission; restart after granting access |
| Space create/delete/move fails | macOS/Yabai compatibility, scripting addition, SIP, sudoers hash |
| Missing native helper | Run `./setup.sh --skip-packages` |
| App icons are boxes | Rice App Icons and JetBrainsMono Nerd Font; log out/in if necessary |
| Theme is out of sync | Reload SketchyBar, then run `~/.config/sketchybar/helpers/native_theme --sync` |
| Bar is missing or stale | `./setup.sh --doctor`; inspect SketchyBar/helper logs |
| Neovim tools are missing | `:ConfigHealth`, `:MasonToolsInstall`, `:checkhealth`; language runtimes |

Native-helper architecture and log paths are in the
[helper guide](../sketchybar/helpers/README.md).

## Restore previous configurations

Setup reports the unique `~/.config/dotfiles-backup.*` folder containing any
conflicting configs and font it moved aside. To undo a linked installation:

1. Stop Yabai, skhd, and SketchyBar.
2. Move the new config symlinks aside.
3. Restore the corresponding directories and font from the reported backup.

Do not move an entire live `~/.config` checkout wholesale. Inspect the specific
links and backup contents before changing anything.

## Configuration map

- Layout and spacing: [yabairc](../yabai/yabairc).
- Bar fonts, widgets, geometry: [sketchybarrc](../sketchybar/sketchybarrc).
- App-glyph overrides: [icon_map.sh](../sketchybar/plugins/icon_map.sh).
- Shared palettes: [catalog.json](../sketchybar/themes/catalog.json).
- Editor behavior: [Neovim guide](../nvim/README.md).

## Checks

Build helpers before running their tests. The installer suite uses temporary
roots and fake service commands; the default helper suite is read-only.

```sh
bash -n setup.sh
python3 -m unittest discover -s tests -p '*_test.py'
python3 -m unittest discover -s sketchybar/helpers/tests -p '*_test.py'
```

Tests that mutate the desktop are opt-in. Do **not** enable
`RICE_THEME_LIVE_TESTS` during ordinary checks: that suite switches the running
desktop through every theme.

Documentation images can be regenerated separately with
`sh docs/media/render.sh`; see the [media guide](media/README.md).

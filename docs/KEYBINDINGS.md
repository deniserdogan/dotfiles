# Keyboard controls

[← Overview](../README.md) · [Setup](SETUP.md)

All `Option` bindings below use **Left Option**. Right Option remains available
to Ghostty for terminal Alt bindings. These shortcuts are global: review
[skhdrc](../skhd/skhdrc) for conflicts with your applications.

## Windows & layouts

| Shortcut | Action |
| --- | --- |
| `Option H / J / K / L` | Focus left / down / up / right, with wraparound |
| `Shift Option H / J / K / L` | Warp the window within the BSP tree |
| `Ctrl Option H / J / K / L` | Resize an edge by 40 px |
| `Option F` | Toggle Yabai zoom; not a macOS fullscreen Space |
| `Option Space` | Toggle floating |
| `Option S` | Toggle split orientation |
| `Shift Option S` | Stack the focused window, or detach it into its own tile |
| `Option [ / ]` | Cycle stack members, wrapping at either end |
| `Option R` | Rotate the layout |
| `Option B` | Balance the layout |
| `Shift Option X / Y` | Mirror the layout |

Option + left/right mouse drag moves/resizes a window.

## Spaces

| Shortcut | Action |
| --- | --- |
| `Cmd 1…9` | Focus a numbered Space; create missing desktops up to that number |
| `Shift Cmd 1…9` | Move the focused window to a numbered Space |
| `Shift Option N` | Create a Space on the focused display |
| `Shift Option Backspace` | Delete the current Space; protect the last one per display |

Pressing the current Space number again returns to the previous desktop.
Semantic numbers follow a desktop between monitors rather than referring to
its temporary Mission Control index. Missing desktops are created on the
focused display.

Space creation, deletion, and movement require the
[advanced setup](SETUP.md#advanced-space-operations).

## Multiple displays

| Shortcut | Action |
| --- | --- |
| `Cmd Option H / J / K / L` | Focus the display in that direction |
| `Cmd Option M` | Cycle display focus |
| `Shift Cmd Option H / J / K / L` | Move the current Space to that display |
| `Shift Cmd Option B` | Move the current Space to the built-in display |
| `Shift Option M` | Repeatedly cycle the Space through connected displays |

## Desktop controls

| Shortcut | Action |
| --- | --- |
| `Cmd Shift S` | Select a screenshot area → clipboard |
| `Ctrl Option Cmd T` | Toggle remembered light/dark themes |
| `Ctrl Option Cmd S` | Reload SketchyBar |
| `Ctrl Option Cmd R` | Restart Yabai |

Screenshot selection uses the macOS capture UI: Esc cancels; Space selects a
window. **`Cmd Shift S` overrides applications' usual Save As shortcut.**

## Neovim

`Space` is the leader key. `gcc` toggles a line comment; visual `gc` comments a
selection. For navigation, language tooling, debugging, and all editor keymaps,
see the [Neovim guide](../nvim/README.md).

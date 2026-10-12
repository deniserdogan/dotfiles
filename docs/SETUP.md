# Setup

[← Overview](../README.md) · [Shortcuts](KEYBINDINGS.md) · [Troubleshooting](MAINTENANCE.md)

## Compatibility

This configuration targets Apple Silicon macOS with Homebrew at `/opt/homebrew`.
It has been used on macOS Tahoe 26.5/26.6. Intel Macs and other platforms need
path and platform changes; the installer deliberately rejects them.
Advanced Space operations also depend on Yabai's support for your macOS version.

## 1. Install prerequisites

Install Apple's Command Line Tools:

```sh
xcode-select --install
```

Install [Homebrew](https://brew.sh/) using its official instructions. Review
the [Brewfile](../Brewfile) for the complete package list.

## 2. Review and install

```sh
git clone https://github.com/deniserdogan/dotfiles.git ~/dotfiles
cd ~/dotfiles
less setup.sh
./setup.sh --dry-run
./setup.sh
```

The installer performs these steps in order:

1. Installs Brewfile dependencies without a blanket upgrade of existing packages.
   Homebrew may still upgrade a dependency when an installation requires it.
2. Builds native helpers **before replacing any configurations**.
3. Links `borders`, `ghostty`, `nvim`, `sketchybar`, `skhd`, and `yabai` into
   `~/.config`. Conflicting folders or symlinks—including broken ones—are moved
   into a unique `~/.config/dotfiles-backup.*` directory, never deleted.
4. Installs the bundled Rice App Icons font, backing up a different existing copy.
5. Creates empty private wallpaper, logo, and cache folders.

Correct links and identical fonts are kept on subsequent runs. A checkout
directly at `~/.config` also works: those directories are left in place.
Users migrating from the old nested `.config/` layout should rerun setup.

**Services stay stopped unless explicitly requested.** The installer does not
change your appearance, wallpaper, launcher artwork, Accessibility permissions,
SIP, or sudoers rules.

## 3. Configure macOS

Before starting the services:

- In **Desktop & Dock → Mission Control**, enable **Displays have separate
  Spaces** and disable **Automatically rearrange Spaces based on most recent
  use**. Log out and back in if macOS requests it.
- Set the macOS menu bar to hide automatically so it does not overlap SketchyBar.
  Look under **Menu Bar** or **Control Center**, depending on macOS version.
- Grant Yabai and skhd access under **Privacy & Security → Accessibility**.
  You may need to launch each once before it appears, then restart it after
  granting access.
- Disable or reassign conflicting `Cmd + number` Mission Control shortcuts
  under **Keyboard → Keyboard Shortcuts**.

## 4. Start and check

```sh
./setup.sh --skip-packages --start-services
./setup.sh --doctor
```

Yabai starts JankyBorders from its config; do not start a second Borders service.
Open Ghostty and run `nvim`. lazy.nvim and Mason bootstrap the editor dependencies.
After the first installation, run `:ConfigHealth` and `:checkhealth` in Neovim.
Language tools may also need Node.js, Go, Python, or other runtimes; see the
[editor guide](../nvim/README.md).

## Advanced Space operations

Basic tiling and many window actions work without Yabai's scripting addition.
Creating, deleting, and moving Spaces—and some focus operations—require it.
On supported macOS versions, enabling it involves **partially disabling System
Integrity Protection (SIP)**. This reduces system protections; make that choice
deliberately.

Setup never changes SIP or sudoers for you. Follow the official instructions
for your exact macOS and Yabai version:

- [SIP requirements](https://github.com/asmvik/yabai/wiki/Disabling-System-Integrity-Protection)
- [Scripting-addition setup](https://github.com/asmvik/yabai/wiki/Installing-yabai-%28latest-release%29#configure-scripting-addition)

Use the documented hash-pinned sudoers rule, not an unrestricted sudo grant.
Refresh its hash after updating Yabai. Machine-specific loaders and sudoers
files are excluded from this repository.

## Installer options

| Option | Behavior |
| --- | --- |
| `--dry-run` | Print the plan without writing, building, or installing |
| `--skip-packages` | Use dependencies already installed through Homebrew |
| `--start-services` | Explicitly start/restart Yabai, skhd, and SketchyBar |
| `--doctor` | Read-only checks for tools, links, icon font, and helpers |

`--doctor` runs alone. The other options may be combined.
See [maintenance](MAINTENANCE.md) for updates and restoring backups.

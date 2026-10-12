#!/usr/bin/env bash
# Review before running. No sudo, privacy changes, or SIP changes.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# Explicit overrides support isolated installer tests; normal installs use HOME.
config_root="${DOTFILES_CONFIG_DIR:-$HOME/.config}"
font_root="${DOTFILES_FONT_DIR:-$HOME/Library/Fonts}"
config_root="${config_root%/}"
font_root="${font_root%/}"
configs=(borders ghostty nvim sketchybar skhd yabai)
dry_run=0
skip_packages=0
start_services=0
doctor=0
backup_dir=""

usage() {
  printf '%s\n' \
    'Usage: ./setup.sh [--dry-run] [--skip-packages] [--start-services]' \
    '       ./setup.sh --doctor' \
    '' \
    'Default: install Brewfile dependencies, build helpers, back up and link configs,' \
    'install the icon font, and create private artwork folders. Services are not restarted.' \
    '  --dry-run         Print the plan without writing, building, or installing.' \
    '  --skip-packages   Use already installed Homebrew dependencies.' \
    '  --start-services  Explicitly start/restart yabai, skhd, and SketchyBar.' \
    '  --doctor          Read-only checks for tools, links, font, and helpers.'
}

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
run() {
  printf '  '
  printf '%q ' "$@"
  printf '\n'
  if (( ! dry_run )); then "$@"; fi
}

while (( $# )); do
  case "$1" in
    --dry-run) dry_run=1 ;;
    --skip-packages) skip_packages=1 ;;
    --start-services) start_services=1 ;;
    --doctor) doctor=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; fail "Unknown option: $1" ;;
  esac
  shift
done
if (( doctor && (dry_run || skip_packages || start_services) )); then
  fail '--doctor cannot be combined with installation options.'
fi
[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] ||
  fail 'This setup currently supports Apple Silicon macOS only.'
[[ "$config_root" == /* && "$font_root" == /* && -n "$config_root" && -n "$font_root" ]] ||
  fail 'Config and font directories must be absolute, non-root paths.'

canonical_directory() {
  local path="$1" suffix=""
  while [[ ! -d "$path" ]]; do
    [[ ! -e "$path" && ! -L "$path" ]] || fail "Not a directory: $path"
    suffix="/$(basename "$path")$suffix"
    path="$(dirname "$path")"
  done
  printf '%s%s\n' "$(cd "$path" && pwd -P)" "$suffix"
}
config_root="$(canonical_directory "$config_root")"
font_root="$(canonical_directory "$font_root")"
[[ "$config_root" != / && "$font_root" != / ]] || fail 'Cannot use a filesystem root.'

tools=(yabai skhd sketchybar borders jq nowplaying-cli nvim rg fd lazygit)
helpers=(native_motion space_controller native_theme RicePanel.app/Contents/MacOS/RicePanel)
if (( doctor )); then
  missing=0
  for tool in brew "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
      printf 'OK   %s\n' "$tool"
    else
      printf 'MISS %s\n' "$tool"; missing=1
    fi
  done
  if xcode-select -p >/dev/null 2>&1; then printf 'OK   Command Line Tools\n';
  else printf 'MISS Command Line Tools (run xcode-select --install)\n'; missing=1; fi
  for name in "${configs[@]}"; do
    if [[ "$repo/$name" -ef "$config_root/$name" ]]; then printf 'OK   %s config\n' "$name";
    else printf 'MISS %s config link\n' "$name"; missing=1; fi
  done
  if [[ -f "$font_root/rice-app-icons.ttf" ]] &&
      cmp -s "$repo/sketchybar/fonts/rice-app-icons.ttf" "$font_root/rice-app-icons.ttf"; then
    printf 'OK   Rice App Icons font\n'
  else printf 'MISS Rice App Icons font\n'; missing=1; fi
  for name in "${helpers[@]}"; do
    if [[ -x "$repo/sketchybar/helpers/$name" ]]; then printf 'OK   %s\n' "$name";
    else printf 'MISS %s (run setup or build.sh)\n' "$name"; missing=1; fi
  done
  printf '\nAccessibility, Mission Control settings, and optional scripting-addition access\n'
  printf 'must be checked manually; see README.md. Nothing was changed.\n'
  exit "$missing"
fi

# Validate every source and unsafe nesting before installing or moving anything.
for name in "${configs[@]}"; do
  [[ -d "$repo/$name" ]] || fail "Missing checkout directory: $name"
  if [[ ! "$repo/$name" -ef "$config_root/$name" ]]; then
    case "$repo/" in
      "$config_root/$name/"*) fail "Checkout is inside $config_root/$name; move it outside the target config first." ;;
    esac
  fi
done
[[ -f "$repo/Brewfile" && -f "$repo/sketchybar/fonts/rice-app-icons.ttf" &&
   -f "$repo/sketchybar/helpers/build.sh" ]] || fail 'Checkout is incomplete.'

if (( ! dry_run )); then
  command -v brew >/dev/null 2>&1 || fail 'Install Homebrew first: https://brew.sh/'
  [[ "$(brew --prefix)" == /opt/homebrew ]] || fail 'Configs currently require Homebrew at /opt/homebrew.'
  xcode-select -p >/dev/null 2>&1 || fail 'Install Apple Command Line Tools: xcode-select --install'
fi
printf 'Checkout: %s\nConfigs:  %s\n' "$repo" "$config_root"
if (( ! skip_packages )); then
  run brew bundle install --file "$repo/Brewfile" --no-upgrade
fi
if (( ! dry_run )); then
  for tool in "${tools[@]}"; do
    command -v "$tool" >/dev/null 2>&1 || fail "Missing $tool; run setup without --skip-packages."
  done
fi
# A failed compiler must not replace any existing user configuration.
run sh "$repo/sketchybar/helpers/build.sh"

backup() {
  local target="$1" name="$2"
  if [[ -z "$backup_dir" ]]; then
    if (( dry_run )); then backup_dir="$config_root/dotfiles-backup.<unique>";
    else backup_dir="$(mktemp -d "$config_root/dotfiles-backup.XXXXXX")"; fi
    printf 'Backup directory: %s\n' "$backup_dir"
  fi
  run mv "$target" "$backup_dir/$name"
}

run mkdir -p "$config_root" "$font_root"
for name in "${configs[@]}"; do
  target="$config_root/$name"
  if [[ "$repo/$name" -ef "$target" ]]; then
    printf '  Keep %s (already using this checkout)\n' "$target"
    continue
  fi
  if [[ -e "$target" || -L "$target" ]]; then backup "$target" "$name"; fi
  run ln -s "$repo/$name" "$target"
done
font="$font_root/rice-app-icons.ttf"
if [[ -f "$font" ]] && cmp -s "$repo/sketchybar/fonts/rice-app-icons.ttf" "$font"; then
  printf '  Keep %s (identical font)\n' "$font"
else
  if [[ -e "$font" || -L "$font" ]]; then backup "$font" rice-app-icons.ttf; fi
  run cp "$repo/sketchybar/fonts/rice-app-icons.ttf" "$font"
fi
run mkdir -p "$config_root/rice/wallpapers" "$config_root/rice/logos" "$config_root/rice/cache"

if (( start_services )); then
  for service in yabai skhd; do
    action=--start-service
    if launchctl print "gui/$(id -u)/com.koekeishiya.$service" >/dev/null 2>&1 ||
       launchctl print "gui/$(id -u)/com.asmvik.$service" >/dev/null 2>&1; then
      action=--restart-service
    fi
    run "$service" "$action"
  done
  run brew services restart sketchybar
  printf 'JankyBorders is started by yabairc; no second border service is needed.\n'
else
  printf '\nServices were not started. Grant Accessibility and review macOS settings, then run:\n'
  printf '  %q --skip-packages --start-services\n' "$repo/setup.sh"
fi
if [[ -n "$backup_dir" ]]; then
  printf '\nPrevious configs/font were preserved in %s\n' "$backup_dir"
  printf 'To restore: stop these services, move the new links aside, and move the backups back.\n'
fi
printf '\nNo wallpaper, logo, appearance, SIP, sudoers, or privacy settings were changed.\n'
if (( dry_run )); then printf 'Dry run only; nothing was written or executed.\n'; fi

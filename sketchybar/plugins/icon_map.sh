#!/usr/bin/env sh

# All app logos use monochrome font outlines, including Incy.
if [ "${2:-}" = "--image" ]; then
  exit 0
fi

# Branded ligatures from sketchybar-app-font.
case "$1" in
  "Activity Monitor") printf ":activity_monitor:" ;;
  "AmneziaVPN") printf ":amnezia_vpn:" ;;
  "Arc") printf ":arc:" ;;
  "Brave Browser"|"Brave Browser Beta"|"Brave Browser Nightly") printf ":brave_browser:" ;;
  "Calendar") printf ":calendar:" ;;
  "ChatGPT"|"ChatGPT Classic") printf ":openai:" ;;
  "ChatGPT Atlas") printf ":chatgpt_atlas:" ;;
  "Code"|"Code - Insiders"|"Visual Studio Code") printf ":code:" ;;
  "Cursor") printf ":cursor:" ;;
  *"Codex"*) printf ":codex:" ;;
  "Discord"|"Discord Canary"|"Discord PTB") printf ":discord:" ;;
  "Docker"|"Docker Desktop") printf ":docker:" ;;
  "Figma") printf ":figma:" ;;
  "Finder") printf ":finder:" ;;
  "Firefox"|"Firefox Developer Edition") printf ":firefox:" ;;
  "Google Chrome"|"Google Chrome Canary"|"Chromium") printf ":google_chrome:" ;;
  "Ghostty") printf ":ghostty:" ;;
  "INCY"|"Incy"|"incy") printf '\356\244\200' ;;
  "iTerm2") printf ":iterm:" ;;
  "kitty") printf ":kitty:" ;;
  "Mail"|"Microsoft Outlook") printf ":mail:" ;;
  "Messages") printf ":messages:" ;;
  "Microsoft Teams"|"Microsoft Teams (work or school)") printf ":microsoft_teams:" ;;
  "Music") printf ":music:" ;;
  "Neovide"|"MacVim") printf ":neovide:" ;;
  "Neovim") printf ":neovim:" ;;
  "Notion") printf ":notion:" ;;
  "Obsidian") printf ":obsidian:" ;;
  "Podcasts"|"Apple Podcasts"|"Подкасты"|"Подкасти"|"播客") printf ":podcasts:" ;;
  "Preview") printf ":preview:" ;;
  "Safari"|"Safari Technology Preview") printf ":safari:" ;;
  "Signal") printf ":signal:" ;;
  "Slack") printf ":slack:" ;;
  "Spotify") printf ":spotify:" ;;
  "System Settings"|"System Preferences") printf ":gear:" ;;
  "Telegram") printf ":telegram:" ;;
  "Terminal"|"WezTerm") printf ":terminal:" ;;
  "Xcode") printf ":xcode:" ;;
  "Zed") printf ":zed:" ;;
  "zoom.us"|"zoom.us.app") printf ":zoom:" ;;
  *) /bin/sh "$(dirname "$0")/../fonts/app_glyphs.sh" "$1" ;;
esac

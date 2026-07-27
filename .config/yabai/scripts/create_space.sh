#!/usr/bin/env sh

yabai -m space --create || exit 1
/bin/sh "$HOME/.config/yabai/scripts/refresh_space_topology.sh"

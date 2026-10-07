# Native Space creation fix for macOS 26.6

This is a side-by-side build from the official yabai repository, commit
`dd845723416f5fe92af49fad5ebab00369e07edd`:
https://github.com/asmvik/yabai/commit/dd845723416f5fe92af49fad5ebab00369e07edd

The maintainer's fix updates the Apple Silicon `addSpace` signature for macOS
26.6 and bumps the scripting addition to 2.1.30. This binary is only used with
`--load-sa`. The Homebrew daemon and its code signature remain untouched; all
normal window/Space commands still use `/opt/homebrew/bin/yabai`.

This note records the local compatibility workaround; it is not an automatic
installer. The compiled loader, machine-specific installer and sudoers rules
are deliberately excluded from Git. Prefer a released yabai version with the
fix when available. To reproduce an older side-by-side setup, build the official
commit using Apple's Command Line Tools and the upstream build instructions.
Install the signed loader into a root-owned directory and configure a sudoers
rule pinned to your own username, binary path and SHA-256, permitting only
`--load-sa`. Do not reuse another machine's hash or grant general sudo access.

Dock restarts to load the updated scripting addition. Existing apps and
desktops remain open. Startup/Dock-restart hooks choose the fixed loader once
installed at `/usr/local/libexec/yabai-native-fix/yabai`, otherwise they keep
using the original Homebrew loader. Follow the official scripting-addition and
SIP instructions linked in the main README; this workaround does not replace
those prerequisites.

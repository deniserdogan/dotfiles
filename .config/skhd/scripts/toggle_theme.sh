#!/usr/bin/env sh

user_id="$(/usr/bin/id -u)"
request_lock="/tmp/theme_request_$user_id"
worker_lock="/tmp/theme_worker_$user_id"
worker_pid_file="/tmp/theme_worker_$user_id.pid"
desired_file="/tmp/theme_desired_$user_id"
pending_file="/tmp/sketchybar_theme_pending_$user_id"
state_file="/tmp/sketchybar_theme_mode_$user_id"

current_system_theme() {
  if [ "$(/usr/bin/defaults read -g AppleInterfaceStyle 2>/dev/null)" = "Dark" ]; then
    /usr/bin/printf dark
  else
    /usr/bin/printf light
  fi
}

acquire_request_lock() {
  attempt=0
  while ! /bin/mkdir "$request_lock" 2>/dev/null; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 100 ] || return 1
    /bin/sleep 0.01
  done
}

release_request_lock() {
  /bin/rmdir "$request_lock" 2>/dev/null || true
}

cleanup_worker() {
  # Never leave the live bar hidden or offscreen if interrupted mid-swap.
  /opt/homebrew/bin/sketchybar \
    --bar hidden=off y_offset=5 >/dev/null 2>&1 || true
  /bin/rm -f \
    "$pending_file" \
    "$worker_pid_file" \
    "$desired_file"
  /bin/rmdir "$request_lock" 2>/dev/null || true
  /bin/rmdir "$worker_lock" 2>/dev/null || true
}

acquire_request_lock || exit 0

is_worker=false
if [ -d "$worker_lock" ]; then
  worker_pid=""
  [ -r "$worker_pid_file" ] &&
    worker_pid="$(/bin/cat "$worker_pid_file" 2>/dev/null)"
  if [ -z "$worker_pid" ] ||
    ! /bin/kill -0 "$worker_pid" 2>/dev/null; then
    /bin/rm -f "$worker_pid_file" "$desired_file"
    /bin/rmdir "$worker_lock" 2>/dev/null || true
  fi
fi

if [ -d "$worker_lock" ]; then
  base_theme="$(/bin/cat "$desired_file" 2>/dev/null)"
  if [ "$base_theme" != "dark" ] && [ "$base_theme" != "light" ]; then
    base_theme="$(current_system_theme)"
  fi
elif /bin/mkdir "$worker_lock" 2>/dev/null; then
  is_worker=true
  /usr/bin/printf '%s\n' "$$" >"$worker_pid_file"
  base_theme="$(current_system_theme)"
else
  release_request_lock
  exit 0
fi

if [ "$base_theme" = "dark" ]; then
  /usr/bin/printf 'light\n' >"$desired_file"
else
  /usr/bin/printf 'dark\n' >"$desired_file"
fi

release_request_lock

# The existing worker will observe the newly updated desired state.
[ "$is_worker" = "true" ] || exit 0
trap cleanup_worker EXIT INT TERM HUP

while :; do
  # Trailing-edge debounce: wait until presses have been quiet for 180 ms.
  target_theme="$(/bin/cat "$desired_file" 2>/dev/null)"
  [ "$target_theme" = "dark" ] || target_theme=light
  /bin/sleep 0.18

  acquire_request_lock || continue
  latest_theme="$(/bin/cat "$desired_file" 2>/dev/null)"
  if [ "$latest_theme" != "$target_theme" ]; then
    release_request_lock
    continue
  fi
  release_request_lock

  actual_theme="$(current_system_theme)"
  if [ "$actual_theme" != "$target_theme" ]; then
    if [ "$target_theme" = "dark" ]; then
      dark_mode=true
    else
      dark_mode=false
    fi

    /usr/bin/printf '%s\n' "$target_theme" >"$pending_file"
    /usr/bin/printf '%s\n' "$target_theme" >"$state_file"

    # Preserve the native-looking window appearance without restarting the
    # service. Prepare the complete palette just above the screen first, then
    # start macOS and the bar entrance together so neither visibly lags behind.
    /opt/homebrew/bin/sketchybar --bar hidden=on y_offset=-32
    /opt/homebrew/bin/sketchybar --bar hidden=off
    CONFIG_DIR=$HOME/.config/sketchybar \
      FORCE_THEME_UPDATE=1 \
      SKIP_NVIM_SYNC=1 \
      THEME_MODE="$target_theme" \
      $HOME/.config/sketchybar/plugins/theme_changed.sh

    /usr/bin/osascript \
      -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark_mode" &
    appearance_pid=$!

    /opt/homebrew/bin/sketchybar \
      --animate tanh 16 \
      --bar y_offset=5

    wait "$appearance_pid" 2>/dev/null || true
    /bin/rm -f "$pending_file"
    /usr/bin/pkill -USR1 -x nvim >/dev/null 2>&1 || true
  fi

  # If intent changed during the completed transition, settle the latest value
  # in one more fully serialized pass. Otherwise release the worker.
  acquire_request_lock || continue
  latest_theme="$(/bin/cat "$desired_file" 2>/dev/null)"
  if [ "$latest_theme" = "$target_theme" ]; then
    /bin/rm -f "$worker_pid_file" "$desired_file"
    /bin/rmdir "$worker_lock" 2>/dev/null || true
    release_request_lock
    trap - EXIT INT TERM HUP
    /bin/rm -f "$pending_file"
    exit 0
  fi
  release_request_lock
done

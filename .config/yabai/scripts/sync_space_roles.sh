#!/usr/bin/env sh

STATE_FILE="$HOME/.config/yabai/space_roles.tsv"
[ -f "$STATE_FILE" ] || : > "$STATE_FILE"

attempt=0
while ! spaces="$(yabai -m query --spaces 2>/dev/null)"; do
  attempt=$((attempt + 1))
  [ "$attempt" -lt 20 ] || exit 1
  sleep 0.1
done
rows="$(
  printf '%s' "$spaces" | jq -r '
    .[]
    | select(."is-native-fullscreen" == false)
    | [
        (if .uuid != "" then .uuid else "id:\(.id)" end),
        .index,
        .label
      ]
    | @tsv
  '
)"

next_role() {
  number=1
  while awk -v role="slot.$number" '$2 == role { found=1 } END { exit !found }' "$STATE_FILE"; do
    number=$((number + 1))
  done
  printf 'slot.%s' "$number"
}

while IFS="$(printf '\t')" read -r key index current_label; do
  [ -n "$key" ] && [ -n "$index" ] || continue

  role="$(awk -v key="$key" '$1 == key { print $2; exit }' "$STATE_FILE")"
  if [ -z "$role" ]; then
    case "$current_label" in
      slot.[0-9]*) role="$current_label" ;;
      *) role="$(next_role)" ;;
    esac
    printf '%s\t%s\n' "$key" "$role" >> "$STATE_FILE"
  fi

  if [ "$current_label" != "$role" ]; then
    yabai -m space "$index" --label "$role" >/dev/null 2>&1
  fi
done <<EOF
$rows
EOF

#!/bin/sh

set -eu

AEROSPACE_BIN="/opt/homebrew/bin/aerospace"
POSITIONS_SCRIPT="/Users/adrian/.config/sketchybar/scripts/list_visible_window_x_positions.sh"

layout="$("$AEROSPACE_BIN" list-workspaces --focused --format '%{workspace-root-container-layout}' 2>/dev/null | tr -d '\r\n')"
printf 'layout|%s\n' "$layout"

if [ "$layout" != "h_accordion" ]; then
  exit 0
fi

focused_id="$("$AEROSPACE_BIN" list-windows --focused --format '%{window-id}' 2>/dev/null | tr -d '\r\n')"
printf 'focused|%s\n' "$focused_id"
printf 'windows-begin\n'
"$AEROSPACE_BIN" list-windows --workspace focused --format '%{window-id}|%{app-name}|%{window-title}'
printf 'windows-end\n'
printf 'positions-begin\n'
"$POSITIONS_SCRIPT"
printf 'positions-end\n'

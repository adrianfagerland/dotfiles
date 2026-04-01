#!/bin/sh

set -eu

AEROSPACE_BIN="/opt/homebrew/bin/aerospace"
CONFIG_FILE="$HOME/.aerospace.toml"
DEFAULT_GAP="10"
ACCORDION_GAP="40"

mode="${1:-auto}"

case "$mode" in
  on)
    desired_gap="$ACCORDION_GAP"
    ;;
  off)
    desired_gap="$DEFAULT_GAP"
    ;;
  auto)
    layout="$("$AEROSPACE_BIN" list-workspaces --focused --format '%{workspace-root-container-layout}' 2>/dev/null | tr -d '\r\n')"
    if [ "$layout" = "h_accordion" ]; then
      desired_gap="$ACCORDION_GAP"
    else
      desired_gap="$DEFAULT_GAP"
    fi
    ;;
  *)
    echo "usage: $0 [on|off|auto]" >&2
    exit 1
    ;;
esac

current_gap="$(sed -nE 's/^outer\.bottom = ([0-9]+)$/\1/p' "$CONFIG_FILE" | head -n 1)"

if [ -z "$current_gap" ] || [ "$current_gap" = "$desired_gap" ]; then
  exit 0
fi

/usr/bin/perl -0pi -e "s/^outer\\.bottom = [0-9]+\$/outer.bottom = $desired_gap/m" "$CONFIG_FILE"
"$AEROSPACE_BIN" reload-config >/dev/null 2>&1 || true

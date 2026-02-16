#!/usr/bin/env bash
set -euo pipefail

BINDINGS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/bindings.conf"

if [[ ! -f "$BINDINGS_FILE" ]]; then
  notify-send "Hyprland" "bindings.conf nicht gefunden"
  exit 1
fi

list_bindings() {
  # Reads bindings.conf and prints one binding per line for rofi
  awk -F '=' '
    /^#/ || NF < 2 { next }
    {
      line = $2
      gsub(/^ +| +$/, "", line)
      split(line, seg, ",")
      for (i in seg) {
        gsub(/^ +| +$/, "", seg[i])
      }
      mod = seg[1]
      key = seg[2]
      desc = seg[3]
      action = seg[4]

      combo = (mod && key) ? mod " + " key : key
      if (!combo) { combo = "Unbekannt" }
      if (!desc) { desc = "Keine Beschreibung" }
      if (!action) { action = "?" }

      print combo "  —  " desc " [" action "]"
    }
  ' "$BINDINGS_FILE"
}

list_bindings | rofi -dmenu -i -p "Hypr Bindings" >/dev/null

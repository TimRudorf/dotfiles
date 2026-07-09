#!/usr/bin/env bash
# RAM-Auslastung fuers tmux-Statusmodul auf Basis von Apples memory_pressure.
#
# Zeigt "belegt"% = 100 - freie%. Hintergrund: der tmux-cpu-Default
# ram_percentage (used/total aus vm_stat) laeuft auf macOS konstruktions-
# bedingt dauerhaft ~85-99%, weil "Pages free" praktisch immer winzig ist
# (macOS haelt fast das ganze RAM warm). memory_pressure ist die Metrik, die
# macOS selbst zur Speichergesundheit nutzt und die zu iStat / Activity Monitor
# passt. Siehe Vault: referenz/nerd-font-glyph-rendering (Kontext tmux-Statusbar).
free=$(/usr/bin/memory_pressure 2>/dev/null \
  | awk -F': ' '/free percentage/ { gsub(/[^0-9]/, "", $2); print $2; exit }')

if [ -z "$free" ]; then
  printf '?%%'
  exit 0
fi

printf '%d%%' "$(( 100 - free ))"

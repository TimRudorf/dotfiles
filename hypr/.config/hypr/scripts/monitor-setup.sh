#!/usr/bin/env bash
# Dynamische Workspace-Zuweisung basierend auf angeschlossenen Monitoren.
# Wird beim Start und bei Monitor-Änderungen aufgerufen.

set -euo pipefail

INTERNAL="eDP-1"

monitors=$(hyprctl monitors -j | jq -r '.[].name')

has_dp2=false
has_dp3=false
external=""
external_count=0

for mon in $monitors; do
    case "$mon" in
        "$INTERNAL") ;;
        "DP-2") has_dp2=true; external_count=$((external_count + 1)) ;;
        "DP-3") has_dp3=true; external_count=$((external_count + 1)) ;;
        *) external="$mon"; external_count=$((external_count + 1)) ;;
    esac
done

assign() {
    hyprctl keyword workspace "$1, monitor:$2" >/dev/null
}

if $has_dp2 && $has_dp3; then
    # Szenario 2: Docking-Station — eDP-1 + DP-2 (landscape) + DP-3 (portrait)
    for ws in 1 2 3 4 5; do assign "$ws" "DP-2"; done
    for ws in 6 7;       do assign "$ws" "DP-3"; done
    for ws in 8 9;       do assign "$ws" "$INTERNAL"; done
elif [[ $external_count -eq 1 ]]; then
    # Szenario 3: Ein externer Monitor (beliebig)
    ext="${external:-DP-2}"
    $has_dp2 && ext="DP-2"
    $has_dp3 && ext="DP-3"
    for ws in 1 2 3 4 5; do assign "$ws" "$ext"; done
    for ws in 6 7 8 9;   do assign "$ws" "$INTERNAL"; done
else
    # Szenario 1: Nur interner Monitor
    for ws in 1 2 3 4 5; do assign "$ws" "$INTERNAL"; done
fi

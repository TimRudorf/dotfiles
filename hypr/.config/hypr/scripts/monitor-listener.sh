#!/usr/bin/env bash
# Lauscht auf Hyprland Monitor-Events und triggert Workspace-Neuzuweisung.

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

socat -U - "UNIX-CONNECT:$SOCKET" | while IFS= read -r line; do
    case "$line" in
        monitoradded*|monitorremoved*)
            sleep 1
            "$SCRIPT_DIR/monitor-setup.sh"
            ;;
    esac
done

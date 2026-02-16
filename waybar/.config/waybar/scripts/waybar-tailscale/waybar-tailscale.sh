#!/usr/bin/env bash

tailscale_is_running() {
    local state
    state="$(tailscale status --json 2>/dev/null | jq -r '.BackendState // empty')"
    [[ "$state" == "Running" ]]
}

toggle_status() {
    if tailscale_is_running; then
        tailscale down
    else
        tailscale up
    fi
    sleep 5
}

case "${1:-}" in
    --status)
        if tailscale_is_running; then
            peers=$(tailscale status --json | jq -r '.Peer[]? | ("<span color=" + (if .Online then "'\''green'\''" else "'\''red'\''" end) + ">" + (.DNSName | split(".")[0]) + "</span>")' | tr '\n' '\r')
            exitnode=$(tailscale status --json | jq -r '.Peer[]? | select(.ExitNode == true).DNSName | split(".")[0]')
            echo "{\"text\":\"${exitnode}\",\"class\":\"connected\",\"alt\":\"connected\",\"tooltip\":\"${peers}\"}"
        else
            echo "{\"text\":\"\",\"class\":\"stopped\",\"alt\":\"stopped\",\"tooltip\":\"VPN is not active.\"}"
        fi
        ;;
    --toggle)
        toggle_status
        ;;
esac

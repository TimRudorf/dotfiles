#!/usr/bin/env bash
# Screenshot-Script für Hyprland (grim + slurp + wl-copy)
# Verwendung: screenshot.sh <mode> <target>
#   mode:   region | screen
#   target: clipboard | file | both

set -euo pipefail

mode="${1:?Verwendung: screenshot.sh <region|screen> <clipboard|file|both>}"
target="${2:?Verwendung: screenshot.sh <region|screen> <clipboard|file|both>}"

screenshot_dir="$HOME/Pictures/Screenshots"
filename="$(date +%Y-%m-%d_%H-%M-%S).png"
filepath="$screenshot_dir/$filename"

take_screenshot() {
    case "$mode" in
        region)
            geometry=$(slurp) || exit 0
            grim -g "$geometry" "$@"
            ;;
        screen)
            grim "$@"
            ;;
        *)
            notify-send "Screenshot" "Unbekannter Modus: $mode" -u critical
            exit 1
            ;;
    esac
}

case "$target" in
    clipboard)
        take_screenshot - | wl-copy
        notify-send "Screenshot" "In Clipboard kopiert"
        ;;
    file)
        mkdir -p "$screenshot_dir"
        take_screenshot "$filepath"
        notify-send "Screenshot" "Gespeichert: $filename"
        ;;
    both)
        mkdir -p "$screenshot_dir"
        take_screenshot "$filepath"
        wl-copy < "$filepath"
        notify-send "Screenshot" "Gespeichert & kopiert: $filename"
        ;;
    *)
        notify-send "Screenshot" "Unbekanntes Ziel: $target" -u critical
        exit 1
        ;;
esac

#!/usr/bin/env bash
# Screenrecord-Script für Hyprland (wl-screenrec + slurp)
# Verwendung: screenrecord.sh <mode>
#   mode: screen | region
# Beim erneuten Aufruf wird eine laufende Aufnahme gestoppt.

RECORDING_DIR="$HOME/Videos/Recordings"
export LIBVA_DRIVER_NAME=radeonsi
WL_SCREENREC=(wl-screenrec --dri-device /dev/dri/renderD129)

# Laufende Aufnahme stoppen
if pgrep -x wl-screenrec >/dev/null; then
    pkill -INT -x wl-screenrec
    notify-send "Aufnahme" "Aufnahme gestoppt"
    exit 0
fi

mode="${1:?Verwendung: screenrecord.sh <screen|region>}"
mkdir -p "$RECORDING_DIR"
filename="$(date +%Y-%m-%d_%H-%M-%S).mp4"
filepath="$RECORDING_DIR/$filename"

case "$mode" in
    region)
        geometry=$(slurp) || exit 0
        "${WL_SCREENREC[@]}" -g "$geometry" -f "$filepath" &
        disown
        ;;
    screen)
        "${WL_SCREENREC[@]}" -f "$filepath" &
        disown
        ;;
    *)
        notify-send "Aufnahme" "Unbekannter Modus: $mode" -u critical
        exit 1
        ;;
esac

notify-send "Aufnahme" "Aufnahme gestartet: $filename"

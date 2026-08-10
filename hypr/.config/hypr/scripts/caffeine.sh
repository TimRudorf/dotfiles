#!/usr/bin/env bash
# Caffeine — hält den Rechner für einen begrenzten Zeitraum wach.
#
# Wer schläfert ein? Zwei Instanzen, und beide hören auf dasselbe Signal:
#   * hypridle  sperrt nach 5 min (hyprlock) und schaltet nach 5,5 min den
#               Bildschirm ab. Es fragt vor jedem Idle-Ereignis die logind-
#               Eigenschaft BlockInhibited ab und überspringt seine Regeln,
#               sobald dort "idle" steht.
#   * logind    behandelt Ruhezustand und Deckel-Schalter (HandleLidSwitch=suspend)
#               und respektiert Block-Inhibitoren auf "sleep" bzw.
#               "handle-lid-switch".
#
# Ein einziger systemd-inhibit-Prozess deckt daher beides ab. Nichts wird
# dauerhaft umkonfiguriert: endet der Prozess — durch Ablauf der Zeit, durch
# "aus" oder durch Abmelden —, gilt sofort wieder die normale Einstellung.

set -euo pipefail

SKRIPT="$(realpath "${BASH_SOURCE[0]}")"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/caffeine"
ENDE_DATEI="$STATE_DIR/ende"
WAYBAR_SIGNAL=9

# Bewusst nur ein Symbol für beide Zustände: die Nerd-Font-Codepunkte haben sich
# zwischen Version 2 und 3 verschoben, und auf diesem Rechner rendert Waybar über
# einen Fallback (die in style.css genannte Maple Mono NF ist nicht installiert).
# Ein zweites, "durchgestrichenes" Symbol traf dabei ein völlig fremdes Zeichen.
# Den Zustand tragen deshalb Farbe und Restzeit, nicht die Glyphe.
ICON="󰅶"

# --- Grundlagen ---------------------------------------------------------------

# Die laufende Sperre wird nicht über eine PID-Datei verfolgt, sondern über die
# Kommandozeile des Inhibitors. Das überlebt einen Absturz des Skripts und kann
# nicht auf eine wiederverwendete PID hereinfallen.
#
# Das Muster ist am Programmnamen verankert: ohne "^systemd-inhibit" träfe es
# auch jede Shell, die "--who=caffeine" nur als Argument in ihrer eigenen
# Kommandozeile stehen hat — die Sperre gälte dann als aktiv, obwohl sie längst
# beendet ist.
laufende_pid() {
	pgrep -u "$(id -u)" -f '^systemd-inhibit .*--who=caffeine' | head -n1
}

aktiv() {
	[[ -n "$(laufende_pid)" ]]
}

waybar_wecken() {
	pkill -RTMIN+$WAYBAR_SIGNAL waybar 2>/dev/null || true
}

melden() {
	command -v notify-send >/dev/null || return 0
	notify-send -a Caffeine -h string:x-dunst-stack-tag:caffeine "$1" "${2:-}"
}

restzeit_sekunden() {
	local ende
	[[ -r "$ENDE_DATEI" ]] || return 1
	ende="$(<"$ENDE_DATEI")"
	[[ "$ende" == "dauerhaft" ]] && return 1
	echo $(( ende - $(date +%s) ))
}

# 5400 -> "1 h 30 min"
lesbar() {
	local s="$1" h m
	(( s < 0 )) && s=0
	h=$(( s / 3600 ))
	m=$(( (s % 3600 + 59) / 60 ))
	(( m == 60 )) && { h=$(( h + 1 )); m=0; }
	if (( h > 0 )); then
		(( m > 0 )) && echo "${h} h ${m} min" || echo "${h} h"
	else
		echo "${m} min"
	fi
}

# --- Schalten -----------------------------------------------------------------

stoppen_still() {
	local pid pgid
	pid="$(laufende_pid)" || true
	rm -f "$ENDE_DATEI"
	[[ -z "$pid" ]] && return 0
	# Die ganze Prozessgruppe beenden: der Inhibitor hält ein "sleep", das sonst
	# als Waise weiterliefe und beim Ablauf noch eine Meldung abfeuern würde.
	pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
	if [[ -n "$pgid" ]]; then
		kill -TERM -- "-$pgid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
	else
		kill -TERM "$pid" 2>/dev/null || true
	fi
}

# starten <sekunden|dauerhaft> [deckel]
starten() {
	local dauer="$1" deckel="${2:-}"
	local was="idle:sleep"
	local grund="Caffeine: Sperre und Ruhezustand vorübergehend ausgesetzt"
	local text

	if [[ "$deckel" == "deckel" ]]; then
		was="idle:sleep:handle-lid-switch"
		grund="Caffeine: wach bleiben, auch bei geschlossenem Deckel"
	fi

	stoppen_still
	mkdir -p "$STATE_DIR"

	if [[ "$dauer" == "dauerhaft" ]]; then
		printf 'dauerhaft\n' >"$ENDE_DATEI"
		text="bis auf Widerruf"
		setsid -f systemd-inhibit \
			--what="$was" --who=caffeine --why="$grund" --mode=block \
			sleep infinity >/dev/null 2>&1
	else
		printf '%s\n' "$(( $(date +%s) + dauer ))" >"$ENDE_DATEI"
		text="für $(lesbar "$dauer")"
		# Der Inhibitor räumt nach Ablauf selbst auf und meldet sich ab, damit ein
		# stiller Übergang zurück in den Normalzustand nicht unbemerkt bleibt.
		setsid -f systemd-inhibit \
			--what="$was" --who=caffeine --why="$grund" --mode=block \
			bash -c 'sleep "$1"; rm -f "$2"; "$3" melden-ende' \
			-- "$dauer" "$ENDE_DATEI" "$SKRIPT" >/dev/null 2>&1
	fi

	[[ "$deckel" == "deckel" ]] && text="$text, auch bei geschlossenem Deckel"
	melden "$ICON  Caffeine an" "Der Rechner bleibt $text wach."
	waybar_wecken
}

aus() {
	if aktiv; then
		stoppen_still
		melden "$ICON  Caffeine aus" "Sperre und Ruhezustand sind wieder aktiv."
	fi
	waybar_wecken
}

# --- Anzeige ------------------------------------------------------------------

# 5400 -> "1h30", 2700 -> "45m" — kompakt genug für die Leiste.
kurz() {
	local s="$1" h m
	(( s < 0 )) && s=0
	h=$(( s / 3600 ))
	m=$(( (s % 3600 + 59) / 60 ))
	(( m == 60 )) && { h=$(( h + 1 )); m=0; }
	if (( h > 0 )); then
		(( m > 0 )) && printf '%dh%02d' "$h" "$m" || printf '%dh' "$h"
	else
		printf '%dm' "$m"
	fi
}

waybar_json() {
	local rest text tooltip
	if aktiv; then
		if rest="$(restzeit_sekunden)"; then
			text="$ICON  $(kurz "$rest")"
			tooltip="Caffeine an — noch $(lesbar "$rest"), bis $(date -d "@$(<"$ENDE_DATEI")" +%H:%M) Uhr"
		else
			text="$ICON  ∞"
			tooltip="Caffeine an — bis auf Widerruf"
		fi
		printf '{"text":"%s","tooltip":"%s\\n\\nLinksklick: Dauer wählen · Rechtsklick: aus","class":"aktiv","alt":"aktiv"}\n' \
			"$text" "$tooltip"
	else
		printf '{"text":"%s","tooltip":"Caffeine aus — Sperre nach 5 min, Bildschirm aus nach 5,5 min\\n\\nLinksklick: wach halten","class":"inaktiv","alt":"inaktiv"}\n' \
			"$ICON"
	fi
}

status() {
	if aktiv; then
		local rest
		if rest="$(restzeit_sekunden)"; then
			echo "an — noch $(lesbar "$rest")"
		else
			echo "an — bis auf Widerruf"
		fi
		systemd-inhibit --list | awk '/who=caffeine|^caffeine/ {print}' || true
	else
		echo "aus"
	fi
}

menue() {
	local kopf auswahl
	if aktiv; then
		kopf="Aktuell: $(status | head -n1)"
	else
		kopf="Aktuell: aus — Sperre nach 5 min"
	fi

	auswahl="$(
		printf '%s\n' \
			"$ICON  15 Minuten" \
			"$ICON  30 Minuten" \
			"$ICON  1 Stunde" \
			"$ICON  2 Stunden" \
			"$ICON  Bis auf Widerruf" \
			"$ICON  1 Stunde, auch bei geschlossenem Deckel" \
			"✕  Aus" |
			rofi -dmenu -i -p "Caffeine" -mesg "$kopf" || true
	)"

	case "$auswahl" in
		*"15 Minuten"*) starten 900 ;;
		*"30 Minuten"*) starten 1800 ;;
		*"1 Stunde, auch"*) starten 3600 deckel ;;
		*"1 Stunde"*) starten 3600 ;;
		*"2 Stunden"*) starten 7200 ;;
		*"Widerruf"*) starten dauerhaft ;;
		*"Aus"*) aus ;;
		*) exit 0 ;;
	esac
}

# 15m / 30min / 1h / 90 -> Sekunden
in_sekunden() {
	local e="$1"
	case "$e" in
		*h)   echo $(( ${e%h} * 3600 )) ;;
		*min) echo $(( ${e%min} * 60 )) ;;
		*m)   echo $(( ${e%m} * 60 )) ;;
		*s)   echo "${e%s}" ;;
		*[!0-9]*) echo "Ungültige Dauer: $e" >&2; exit 1 ;;
		*)    echo $(( e * 60 )) ;;
	esac
}

# --- Einstieg -----------------------------------------------------------------

case "${1:-menue}" in
	menue|menu) menue ;;
	an|on)
		deckel=""
		[[ "${3:-}" == "deckel" || "${2:-}" == "deckel" ]] && deckel="deckel"
		if [[ -n "${2:-}" && "${2}" != "deckel" ]]; then
			starten "$(in_sekunden "$2")" "$deckel"
		else
			starten dauerhaft "$deckel"
		fi
		;;
	aus|off) aus ;;
	toggle)
		if aktiv; then aus; else starten "$(in_sekunden "${2:-60m}")"; fi
		;;
	waybar) waybar_json ;;
	status) status ;;
	melden-ende)
		melden "$ICON  Caffeine abgelaufen" "Sperre und Ruhezustand sind wieder aktiv."
		waybar_wecken
		;;
	*)
		cat <<-HILFE
			Caffeine — hält den Rechner zeitlich begrenzt wach.

			  caffeine.sh                 Menü (Dauer wählen)
			  caffeine.sh an 30m          30 Minuten wach halten
			  caffeine.sh an 2h deckel    2 Stunden, auch bei geschlossenem Deckel
			  caffeine.sh an              bis auf Widerruf
			  caffeine.sh toggle [dauer]  umschalten (Vorgabe 60m)
			  caffeine.sh aus             sofort beenden
			  caffeine.sh status          Zustand anzeigen

			Dauer: 90 (Minuten), 45min, 2h, 30s
		HILFE
		;;
esac

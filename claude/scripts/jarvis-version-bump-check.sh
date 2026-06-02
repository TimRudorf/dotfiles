#!/usr/bin/env bash
# PreToolUse(Bash)-Guard: blockt `git commit` in EDP-Delphi-Schnittstellen
# (~/dev/EDP/schn_* mit .dproj), wenn shippender Code (.pas/.dpr/.dfm/.inc)
# geaendert wird, aber die FileVersion/VerInfo im .dproj NICHT.
#
# Zweck: erzwingt die bewusste SemVer-Entscheidung vor dem Commit, damit der
# committete (und vom Kollegen aus der IDE ausgelieferte) Stand immer eine
# rueckverfolgbare Version traegt. Siehe Vault:
#   tim/feedback/versionsnummer-bei-code-aenderung.md
#   referenz/edp-schnittstellen-versionierung.md
#
# Eingebunden in settings.json als hooks.PreToolUse Matcher "Bash".
# Exit 2 + stderr blockt den Commit und zeigt Claude den Hinweis.
# Bypass: Token [skip-version] im Commit-Befehl (reine Doku/Test/CI-Aenderung).
# Fail-open: bei jeder Unklarheit exit 0 (nie legitime Commits dauerhaft blocken).

input="$(cat)"

# Schnell-Ausstieg: nur bei git commit ueberhaupt weiterdenken
printf '%s' "$input" | grep -q 'git commit' || exit 0

# Bypass-Token
printf '%s' "$input" | grep -q '\[skip-version\]' && exit 0

# command + effektives Verzeichnis (cwd, oder fuehrendes 'cd <pfad>') aus JSON.
# Python-Programm in SHELL-Single-Quotes -> Python nutzt nur Double-Quotes.
# Ausgabe: "<has_all>\t<dir>".
parsed="$(printf '%s' "$input" | python3 -c '
import sys, json, re, os
try:
    d = json.load(sys.stdin)
except Exception:
    print("0\t"); sys.exit(0)
cmd = (d.get("tool_input", {}) or {}).get("command", "") or ""
cwd = d.get("cwd", "") or ""
m = re.match(r"\s*cd\s+(\"[^\"]+\"|\S+)", cmd)
ddir = ""
if m:
    ddir = os.path.expanduser(m.group(1).strip("\""))
eff = ddir or cwd
allf = "1" if re.search(r"(^|\s)-[A-Za-z]*a[A-Za-z]*(\s|$)|--all", cmd) else "0"
print(allf + "\t" + eff)
' 2>/dev/null)"
cmd_has_all="${parsed%%$'\t'*}"
eff_dir="${parsed#*$'\t'}"

[ -z "$eff_dir" ] && exit 0

root="$(git -C "$eff_dir" rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -z "$root" ] && exit 0

# Nur EDP-Schnittstellen-Repos
case "$root" in
  "$HOME/dev/EDP/schn_"*) ;;
  *) exit 0 ;;
esac

# Nur Delphi (hat .dproj). Go-Schnittstellen: Version = Git-Tag + ReadBuildInfo -> kein Guard.
dproj=""
for f in "$root"/*.dproj; do [ -e "$f" ] && dproj="$f" && break; done
[ -z "$dproj" ] && exit 0
dproj_base="$(basename "$dproj")"

# Geaenderte Dateien (staged; bei -a/-am auch unstaged tracked)
changed="$(git -C "$root" diff --cached --name-only 2>/dev/null)"
if [ "$cmd_has_all" = "1" ]; then
  changed="$changed
$(git -C "$root" diff --name-only 2>/dev/null)"
fi
[ -z "$changed" ] && exit 0

# Shippender Code geaendert?
printf '%s\n' "$changed" | grep -qiE '\.(pas|dpr|dfm|inc)$' || exit 0

# VerInfo/FileVersion im dproj geaendert?
ver_diff="$(git -C "$root" diff --cached -- "$dproj_base" 2>/dev/null)"
if [ "$cmd_has_all" = "1" ]; then
  ver_diff="$ver_diff
$(git -C "$root" diff -- "$dproj_base" 2>/dev/null)"
fi
printf '%s\n' "$ver_diff" | grep -qE '^[+-].*(FileVersion=|VerInfo_(MajorVer|MinorVer|Release|Build|Keys))' && exit 0

# -> shippender Code geaendert, Version aber nicht: blocken
cat >&2 <<EOF
BLOCKED: Versionsnummer nicht angepasst ($(basename "$root")).

Dieser Commit aendert shippenden Code (.pas/.dpr/.dfm/.inc), aber die
FileVersion/VerInfo in $dproj_base bleibt unveraendert.

Triff eine bewusste SemVer-Entscheidung (referenz/edp-schnittstellen-versionierung):
  MAJOR  Breaking (Kunde/Admin muss eingreifen)
  MINOR  neue rueckwaertskompatible Funktion
  PATCH  Bugfix / Kosmetik / Refactor / Dependency-Bump

Setze FileVersion: numerische VerInfo_MajorVer/MinorVer/Release/Build UND den
FileVersion=-String in VerInfo_Keys (alle Release-Configs, synchron halten).

Reine Doku/Test/CI/Kommentar-Aenderung? Dann mit Token [skip-version] im
Commit-Befehl committen.
EOF
exit 2

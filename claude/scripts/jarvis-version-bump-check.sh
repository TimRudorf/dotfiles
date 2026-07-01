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
#
# Haerte gegen die kombinierte-Kommando-Falle: der Hook laeuft VOR der Kommando-
# Ausfuehrung. Bei `git add -A && git commit ...` ist zur Hook-Zeit noch NICHTS
# gestaged -> `git diff --cached` waere leer und der Guard wuerde durchwinken.
# Deshalb wird ein `git add` im selben Befehl erkannt und per `git add --dry-run`
# (seiteneffektfrei) ermittelt, was gestaged WUERDE. Die Pruefung stuetzt sich auf
# die vollstaendige "wird-committet"-Menge:
#   staged  UNION  would-be-added(git add --dry-run)  UNION  (bei -a) unstaged-tracked

input="$(cat)"

# Schnell-Ausstieg: nur bei git commit ueberhaupt weiterdenken
printf '%s' "$input" | grep -q 'git commit' || exit 0

# Bypass-Token
printf '%s' "$input" | grep -q '\[skip-version\]' && exit 0

# command + effektives Verzeichnis (cwd, oder fuehrendes 'cd <pfad>') + die
# Argument-Segmente jedes `git add` im Befehl aus JSON extrahieren.
# Python-Programm in SHELL-Single-Quotes -> Python nutzt nur Double-Quotes.
# Ausgabe (Tab-getrennt, ein Record pro Zeile):
#   HALL <tab> <0|1>     hat -a/--all am commit
#   EDIR <tab> <dir>     effektives Verzeichnis
#   ADDS <tab> <args>    Argument-String je `git add` (0..n Zeilen)
parsed="$(printf '%s' "$input" | python3 -c '
import sys, json, re, os
try:
    d = json.load(sys.stdin)
except Exception:
    print("EDIR\t"); sys.exit(0)
cmd = (d.get("tool_input", {}) or {}).get("command", "") or ""
cwd = d.get("cwd", "") or ""
m = re.match(r"\s*cd\s+(\"[^\"]+\"|\S+)", cmd)
ddir = ""
if m:
    ddir = os.path.expanduser(m.group(1).strip("\""))
eff = ddir or cwd
# -a/--all NUR am commit-Teil bewerten (nicht am ganzen Kommando, sonst wuerde
# z.B. ein Pfad -la faelschlich zaehlen). Der commit-Teil ist alles ab "git commit".
cpos = cmd.find("git commit")
commit_part = cmd[cpos:] if cpos >= 0 else cmd
allf = "1" if re.search(r"(^|\s)-[A-Za-z]*a[A-Za-z]*(\s|$)|--all", commit_part) else "0"
# git-add-Segmente: nur an einer Kommando-Grenze (Start / && / ; / |), damit
# ein "git add" im Commit-Message-Text nicht faelschlich matcht.
adds = re.findall(r"(?:^|&&|;|\|)\s*git\s+add\b([^&;|]*)", cmd)
print("HALL\t" + allf)
print("EDIR\t" + eff)
for seg in adds:
    seg = seg.strip()
    if seg:
        print("ADDS\t" + seg)
' 2>/dev/null)"

cmd_has_all="$(printf '%s\n' "$parsed" | awk -F'\t' '$1=="HALL"{print $2; exit}')"
eff_dir="$(printf '%s\n' "$parsed" | awk -F'\t' '$1=="EDIR"{print substr($0, index($0,"\t")+1); exit}')"
add_segs="$(printf '%s\n' "$parsed" | awk -F'\t' '$1=="ADDS"{print substr($0, index($0,"\t")+1)}')"

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

# Was ein `git add` im selben Befehl stagen WUERDE (seiteneffektfrei ermitteln).
# Dry-run im effektiven Verzeichnis, damit relative Pathspecs so aufloesen wie
# beim echten Lauf. Ausgabeformat "add 'pfad'" -> auf den Pfad reduzieren.
would_add=""
if [ -n "$add_segs" ]; then
  while IFS= read -r seg; do
    [ -z "$seg" ] && continue
    wa="$( ( cd "$eff_dir" 2>/dev/null && eval "git add --dry-run $seg" ) 2>/dev/null \
           | sed -E "s/^add '(.*)'\$/\1/" )"
    would_add="$would_add
$wa"
  done <<SEGS
$add_segs
SEGS
fi

# "wird-committet"-Menge: staged + would-be-added + (bei -a) unstaged tracked.
changed="$(git -C "$root" diff --cached --name-only 2>/dev/null)
$would_add"
if [ "$cmd_has_all" = "1" ]; then
  changed="$changed
$(git -C "$root" diff --name-only 2>/dev/null)"
fi
[ -z "$(printf '%s' "$changed" | tr -d '[:space:]')" ] && exit 0

# Shippender Code in der wird-committet-Menge? (Extension-Match ist robust
# gegen relative/absolute Pfad-Praefixe aus dem dry-run.)
printf '%s\n' "$changed" | grep -qiE '\.(pas|dpr|dfm|inc)$' || exit 0

# Wird der .dproj ueberhaupt mitcommittet? Wenn nein -> keine Version im Commit
# -> blocken. Basename-Match am Zeilenende faengt auch "../Name.dproj" aus dem
# dry-run ab, ohne auf "Name.dproj.bak" o.ae. anzuspringen.
esc_dproj="$(printf '%s' "$dproj_base" | sed -e 's/[.[\*^$/]/\\&/g')"
if printf '%s\n' "$changed" | grep -qE "(^|/)${esc_dproj}\$"; then
  # dproj wird committet -> traegt sein (staged ODER unstaged) Diff einen
  # Versions-Marker? Dann ist der Bump dabei -> durchlassen.
  ver_diff="$(git -C "$root" diff --cached -- "$dproj_base" 2>/dev/null)"
  ver_diff="$ver_diff
$(git -C "$root" diff -- "$dproj_base" 2>/dev/null)"
  printf '%s\n' "$ver_diff" | grep -qE '^[+-].*(FileVersion=|VerInfo_(MajorVer|MinorVer|Release|Build|Keys))' && exit 0
fi

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

#!/usr/bin/env bash
# PostToolUse-Hook: Wenn ein Write/Edit/MultiEdit eine Datei innerhalb des
# jarvis-wiki Vaults verändert hat, committet+pusht der Hook die Änderung
# direkt auf main, damit der Peer-Host sie beim nächsten Pull (Obsidian-Git
# auf Mac, oder SessionStart-Pull) sieht.
#
# Wird von ~/dotfiles/claude/settings.json als hooks.PostToolUse mit
# matcher "Write|Edit|MultiEdit" eingebunden. Läuft auf Mac und Container.
#
# Auf dem Mac läuft parallel das Obsidian-Git-Plugin — der Hook ist
# idempotent (wenn nichts staged → nichts zu tun), deshalb harmlos.
#
# Fail-safe: jeder Fehler -> exit 0, kein Output.

set -u

# --- Stdin lesen + Pfad extrahieren ---
INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat 2>/dev/null || true)
fi
[ -z "$INPUT" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0

FILE_PATH=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    fp = data.get('tool_input', {}).get('file_path', '')
    print(fp)
except Exception:
    pass
" 2>/dev/null || true)
[ -z "$FILE_PATH" ] && exit 0

REAL_PATH=$(python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$FILE_PATH" 2>/dev/null || true)
[ -z "$REAL_PATH" ] && exit 0

# --- Vault-Detection (host-abhängig) ---
VAULT_DIR=""
for candidate in "/workspace/wiki" "$HOME/Documents/jarvis-wiki"; do
  if [ -d "$candidate/.git" ]; then
    VAULT_DIR="$candidate"
    break
  fi
done
[ -z "$VAULT_DIR" ] && exit 0

REAL_VAULT=$(python3 -c "import os; print(os.path.realpath('$VAULT_DIR'))" 2>/dev/null || true)
[ -z "$REAL_VAULT" ] && exit 0

# --- Nur weitermachen, wenn Pfad innerhalb des Vault-Trees liegt ---
case "$REAL_PATH" in
  "$REAL_VAULT"/*) ;;
  *) exit 0 ;;
esac

# --- Host-Detection (für Commit-Message) ---
# Der Name landet in JEDER Vault-Commit-Message und ist die einzige Spur, welcher
# Rechner geschrieben hat. Solange es nur Container und Mac gab, war ein else-Zweig
# auf "mac" richtig; seit Poseidon dazugekommen ist, war er falsch — jeder
# Poseidon-Commit trug "via mac". Bei zwei parallel am selben Vault arbeitenden
# Sitzungen macht das die Historie unbrauchbar, und zwar genau dann, wenn man sie
# am dringendsten braucht.
# uname -n statt hostname: hostname fehlt auf Arch ohne inetutils.
if [ "${JARVIS_HOST:-}" = "container" ] || [ -f /.dockerenv ]; then
  HOST="container"
elif [ -n "${JARVIS_HOST:-}" ]; then
  HOST="$JARVIS_HOST"
elif [ "$(uname -s)" = "Darwin" ]; then
  HOST="mac"
else
  HOST="$(uname -n 2>/dev/null | cut -d. -f1 | tr '[:upper:]' '[:lower:]')"
  [ -z "$HOST" ] && HOST="unbekannt"
fi

REL_PATH="${REAL_PATH#$REAL_VAULT/}"

# --- Git-Operationen (alles fail-safe) ---
{
  cd "$VAULT_DIR" || exit 0

  git add "$REL_PATH" 2>/dev/null || exit 0

  if git diff --cached --quiet -- "$REL_PATH"; then
    exit 0
  fi

  git commit -m "vault: ${REL_PATH} (auto-sync via ${HOST})" --quiet 2>/dev/null || exit 0

  # Pull --rebase davor, falls Peer in der Zwischenzeit gepusht hat.
  # Schlägt der Rebase fehl (Konflikt), NICHT still verschlucken (|| true) —
  # das ließe den Vault im Mid-Rebase hängen (unmerged paths), der Push liefe
  # leer durch und der Peer sähe die neuen Files nie. Stattdessen sauber
  # abbrechen + Breadcrumb loggen (#95).
  if ! git pull --rebase --autostash --quiet 2>/dev/null; then
    git rebase --abort 2>/dev/null || true
    git merge --abort  2>/dev/null || true
    {
      echo "auto-sync pull --rebase fehlgeschlagen bei ${REL_PATH} (${HOST}, $(date -Iseconds))"
      echo "git status:"
      git status --short
    } >> "$VAULT_DIR/.vault-sync-incidents.log" 2>/dev/null || true
  fi

  # Push asynchron im Hintergrund — Hook returned sofort, Claude wartet nicht.
  ( git push origin main --quiet 2>/dev/null & disown ) || true
} >/dev/null 2>&1

exit 0

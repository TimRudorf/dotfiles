#!/usr/bin/env bash
# PostToolUse-Hook: Wenn ein Write/Edit/MultiEdit eine Datei innerhalb von
# ~/dotfiles/claude/memory/ verändert hat, committet+pusht der Hook die
# Änderung direkt auf main, damit der Peer-Host sie beim nächsten
# SessionStart-Pull sieht.
#
# Wird von ~/dotfiles/claude/settings.json als hooks.PostToolUse mit
# matcher "Write|Edit|MultiEdit" eingebunden.
#
# Fail-safe: jeder Fehler -> exit 0, kein Output (Tool-Result bleibt
# unverändert für Claude). Auto-Sync ist dann inaktiv für den Write.

set -u

DOTFILES_DIR="$HOME/dotfiles"
MEMORY_DIR="$DOTFILES_DIR/claude/memory"

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

# --- Realpath auflösen — Memory wird via Symlink unter ~/.claude/projects/<...>/memory/ geschrieben ---
REAL_PATH=$(python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$FILE_PATH" 2>/dev/null || true)
REAL_MEMORY=$(python3 -c "import os; print(os.path.realpath('$MEMORY_DIR'))" 2>/dev/null || true)
[ -z "$REAL_PATH" ] || [ -z "$REAL_MEMORY" ] && exit 0

# --- Nur weitermachen, wenn Pfad innerhalb des Memory-Trees liegt ---
case "$REAL_PATH" in
  "$REAL_MEMORY"/*) ;;
  *) exit 0 ;;
esac

# --- Host-Detection (für Commit-Message) ---
if [ "${JARVIS_HOST:-}" = "container" ] || [ -f /.dockerenv ]; then
  HOST="container"
else
  HOST="mac"
fi

REL_NAME=$(basename "$REAL_PATH")

# --- Git-Operationen (alles fail-safe, keine Fehler nach Claude) ---
{
  cd "$DOTFILES_DIR" || exit 0

  # Stelle sicher dass nur Memory-Änderungen committet werden,
  # nicht versehentlich andere staged Dateien.
  git add "claude/memory/$REL_NAME" 2>/dev/null || exit 0

  # Wenn nichts staged ist (z.B. Edit ohne tatsächliche Änderung), abbrechen.
  if git diff --cached --quiet -- "claude/memory/$REL_NAME"; then
    exit 0
  fi

  git commit -m "memory: ${REL_NAME} (auto-sync via ${HOST})" --quiet 2>/dev/null || exit 0

  # Pull --rebase vor Push, falls Peer in der Zwischenzeit gepusht hat.
  git pull --rebase --autostash --quiet 2>/dev/null || true

  # Push asynchron im Hintergrund — der Hook returned sofort, Claude wartet nicht.
  ( git push origin main --quiet 2>/dev/null & disown ) || true
} >/dev/null 2>&1

exit 0

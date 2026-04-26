#!/usr/bin/env bash
# SessionStart-Hook für Jarvis: stellt sicher, dass das Memory der aktuellen
# Session auf das geteilte ~/dotfiles/claude/memory/ symlinkt — und injiziert
# Self-Awareness-Kontext (JARVIS_HOST, cwd, Memory-Pfad) in die Session.
#
# Wird von ~/dotfiles/claude/settings.json als hooks.SessionStart eingebunden.
# Läuft auf Mac und im jarvis-workspace Container.
#
# Fail-safe: bei jedem Fehler exit 0 mit minimalem Output, damit die Session
# trotzdem startet. Memory-Sharing ist dann inaktiv für die Session.

set -u

DOTFILES_MEMORY="$HOME/dotfiles/claude/memory"

# --- Stdin lesen (Hook-Input-JSON) ---
INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat 2>/dev/null || true)
fi

# --- cwd extrahieren ---
CWD=""
if [ -n "$INPUT" ] && command -v python3 >/dev/null 2>&1; then
  CWD=$(printf '%s' "$INPUT" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('cwd',''))
except Exception: pass" 2>/dev/null || true)
fi
[ -z "$CWD" ] && CWD="$PWD"

# --- Encoded project-dir-Name (slashes -> dashes) ---
ENCODED=$(printf '%s' "$CWD" | sed 's|/|-|g')
PROJECT_DIR="$HOME/.claude/projects/$ENCODED"
MEMORY_DIR="$PROJECT_DIR/memory"

# --- Host-Detection ---
if [ "${JARVIS_HOST:-}" = "container" ] || [ -f /.dockerenv ]; then
  HOST="container"
  PEER="Mac"
else
  HOST="mac"
  PEER="Container"
fi

# --- Memory-Symlink sicherstellen (idempotent) ---
LINK_STATUS="ok"
if [ ! -d "$DOTFILES_MEMORY" ]; then
  LINK_STATUS="dotfiles-memory-missing"
elif [ -L "$MEMORY_DIR" ]; then
  TARGET=$(readlink "$MEMORY_DIR" 2>/dev/null || true)
  if [ "$TARGET" != "$DOTFILES_MEMORY" ]; then
    rm -f "$MEMORY_DIR" 2>/dev/null && \
      ln -s "$DOTFILES_MEMORY" "$MEMORY_DIR" 2>/dev/null && \
      LINK_STATUS="relinked" || LINK_STATUS="relink-failed"
  fi
elif [ -d "$MEMORY_DIR" ]; then
  TS=$(date +%Y%m%d-%H%M%S)
  BACKUP="$HOME/.claude.memory-backup-$TS"
  if mkdir -p "$BACKUP" 2>/dev/null && \
     cp -a "$MEMORY_DIR" "$BACKUP/${HOST}-${ENCODED}" 2>/dev/null && \
     rm -rf "$MEMORY_DIR" 2>/dev/null && \
     ln -s "$DOTFILES_MEMORY" "$MEMORY_DIR" 2>/dev/null; then
    LINK_STATUS="migrated (backup: $BACKUP)"
  else
    LINK_STATUS="migrate-failed"
  fi
elif [ ! -e "$MEMORY_DIR" ]; then
  if mkdir -p "$PROJECT_DIR" 2>/dev/null && \
     ln -s "$DOTFILES_MEMORY" "$MEMORY_DIR" 2>/dev/null; then
    LINK_STATUS="created"
  else
    LINK_STATUS="create-failed"
  fi
fi

# --- additionalContext-Output ---
export JARVIS_HOST_OUT="$HOST"
export JARVIS_PEER_OUT="$PEER"
export JARVIS_CWD_OUT="$CWD"
export JARVIS_MEMORY_OUT="$MEMORY_DIR"
export JARVIS_STATUS_OUT="$LINK_STATUS"

if command -v python3 >/dev/null 2>&1; then
  python3 <<'PYEOF' 2>/dev/null || printf '{"continue":true}\n'
import json, os
ctx = (
    "## Wo du gerade läufst\n\n"
    f"- **JARVIS_HOST:** {os.environ['JARVIS_HOST_OUT']}\n"
    f"- **cwd:** {os.environ['JARVIS_CWD_OUT']}\n"
    f"- **Memory:** {os.environ['JARVIS_MEMORY_OUT']} → ~/dotfiles/claude/memory "
    f"(geteilt mit {os.environ['JARVIS_PEER_OUT']})\n"
    f"- **Symlink-Status:** {os.environ['JARVIS_STATUS_OUT']}\n\n"
    "Memory-Writes wandern automatisch ins gemeinsame dotfiles-Repo. "
    f"Beide Hosts (Mac und {os.environ['JARVIS_PEER_OUT']}) sehen jede neue "
    "Memory-Notiz. Beim Schreiben daran denken, dass die Erkenntnis "
    "hostübergreifend gilt — also keine host-spezifischen Pfade ohne "
    "Klammerzusatz aufschreiben."
)
print(json.dumps({
    "continue": True,
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": ctx,
    },
}))
PYEOF
else
  printf '{"continue":true}\n'
fi

exit 0

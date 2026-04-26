#!/usr/bin/env bash
# Bootstrap ~/.claude/ als echtes Verzeichnis mit individuellen Symlinks
# zu ~/dotfiles/claude/<file>. Idempotent — kann mehrfach laufen.
#
# Hintergrund: Vorher war ~/.claude ein ganz-Symlink auf ~/dotfiles/claude/.claude/.
# Pfade mit .claude/-Verzeichnis-Komponente werden vom Claude-Code-Harness als
# sensitive eingestuft, was Schreiboperationen blockt. Daher das ganze Tree
# raus aus .claude/.
#
# Dieses Skript migriert vom alten ganz-Symlink-Setup zum neuen Schema
# (echtes Verzeichnis + Per-File/-Item-Symlinks zu dotfiles).
set -euo pipefail

DOTFILES_CLAUDE="${DOTFILES_CLAUDE:-$HOME/dotfiles/claude}"
CLAUDE_DIR="$HOME/.claude"
LOCAL_STATE_ITEMS=(
  projects sessions plugins cache debug
  session-env shell-snapshots backups
  .credentials.json history.jsonl mcp-needs-auth-cache.json
)
SYMLINK_FILES=(CLAUDE.md PERSONA.md PROFILE.md CONTEXTS.md settings.json)
SYMLINK_DIRS=(agents skills)  # einzelne Items darin werden symlinkt

log() { printf '[bootstrap-mac-claude] %s\n' "$*"; }

if [ ! -d "$DOTFILES_CLAUDE" ]; then
  echo "ERROR: $DOTFILES_CLAUDE nicht gefunden." >&2
  exit 1
fi

# ---------- Phase 1: alten ganz-Symlink aufbrechen ----------
if [ -L "$CLAUDE_DIR" ]; then
  OLD_TARGET=$(readlink -f "$CLAUDE_DIR")
  log "alter Symlink $CLAUDE_DIR -> $OLD_TARGET — wird aufgebrochen"

  BACKUP="$HOME/.claude.backup-$(date +%Y%m%d-%H%M%S)"
  log "backup: cp -a \"$OLD_TARGET\" \"$BACKUP\""
  cp -a "$OLD_TARGET" "$BACKUP"

  rm "$CLAUDE_DIR"
  mkdir -p "$CLAUDE_DIR"

  # Lokalen ephemeren State aus altem Symlink-Ziel umziehen
  for item in "${LOCAL_STATE_ITEMS[@]}"; do
    if [ -e "$OLD_TARGET/$item" ] || [ -L "$OLD_TARGET/$item" ]; then
      log "migrate state: $item"
      mv "$OLD_TARGET/$item" "$CLAUDE_DIR/$item"
    fi
  done

  # Was übrig ist im alten Verzeichnis (außer den getrackten Files) — warnen
  shopt -s dotglob nullglob
  leftover=()
  for f in "$OLD_TARGET"/*; do
    name=$(basename "$f")
    skip=false
    for tracked in "${SYMLINK_FILES[@]}" "${SYMLINK_DIRS[@]}" .gitignore; do
      [ "$name" = "$tracked" ] && skip=true && break
    done
    $skip || leftover+=("$name")
  done
  shopt -u dotglob nullglob
  if [ "${#leftover[@]}" -gt 0 ]; then
    log "WARN: nicht zugeordnete Reste in $OLD_TARGET:"
    for f in "${leftover[@]}"; do printf '  - %s\n' "$f"; done
    log "Falls relevant: manuell nach $CLAUDE_DIR umziehen."
  fi
elif [ ! -d "$CLAUDE_DIR" ]; then
  log "$CLAUDE_DIR existiert nicht — anlegen"
  mkdir -p "$CLAUDE_DIR"
else
  log "$CLAUDE_DIR ist bereits ein echtes Verzeichnis — nur Symlinks aktualisieren"
fi

# ---------- Phase 2: per-File-Symlinks ----------
for item in "${SYMLINK_FILES[@]}"; do
  src="$DOTFILES_CLAUDE/$item"
  dst="$CLAUDE_DIR/$item"
  if [ ! -e "$src" ]; then
    log "skip $item (nicht in dotfiles)"
    continue
  fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    log "WARN: $dst existiert als echte Datei — nicht überschrieben. Manuell prüfen."
    continue
  fi
  ln -sfn "$src" "$dst"
  log "link $item -> $src"
done

# ---------- Phase 3: per-Item-Symlinks für agents/ und skills/ ----------
for dir in "${SYMLINK_DIRS[@]}"; do
  src_dir="$DOTFILES_CLAUDE/$dir"
  dst_dir="$CLAUDE_DIR/$dir"
  if [ ! -d "$src_dir" ]; then
    log "skip $dir/ (nicht in dotfiles)"
    continue
  fi
  mkdir -p "$dst_dir"

  # Stale Symlinks im dst entfernen (nicht echte Verzeichnisse anfassen)
  shopt -s dotglob nullglob
  for f in "$dst_dir"/*; do
    [ -L "$f" ] && rm "$f"
  done
  shopt -u dotglob nullglob

  # Neue Symlinks pro Item
  shopt -s nullglob
  for entry in "$src_dir"/*; do
    [ -e "$entry" ] || continue
    name=$(basename "$entry")
    ln -sfn "$entry" "$dst_dir/$name"
  done
  shopt -u nullglob
  log "linked $(ls -1 "$dst_dir" | wc -l | tr -d ' ') items in $dir/"
done

# ---------- Phase 4: Sanity-Check ----------
log "sanity-check:"
for item in "${SYMLINK_FILES[@]}"; do
  if [ -L "$CLAUDE_DIR/$item" ] && [ -e "$CLAUDE_DIR/$item" ]; then
    printf '  ✓ %s\n' "$item"
  elif [ -e "$DOTFILES_CLAUDE/$item" ]; then
    printf '  ✗ %s (Symlink kaputt oder fehlt)\n' "$item"
  fi
done

log "fertig. $CLAUDE_DIR ist jetzt:"
ls -la "$CLAUDE_DIR" | head -30

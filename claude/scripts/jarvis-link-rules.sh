#!/usr/bin/env bash
# Verknüpft geteilte und host-spezifische Regeln nach ~/.claude/rules/.
#
# Claude Code findet .md-Dateien unter ~/.claude/rules/ rekursiv und löst
# Symlinks dabei auf. Deshalb ist ~/.claude/rules/ ein ECHTES Verzeichnis mit
# Symlinks darin — und nicht selbst ein Symlink ins Repo: sonst gäbe es keinen
# Platz für host-spezifische und lokale Regeln daneben.
#
# Idempotent. Nach jedem dotfiles-Pull gefahrlos erneut ausführbar.
set -euo pipefail

DOTFILES="${DOTFILES_DIR:-$HOME/dotfiles}"
RULES="$HOME/.claude/rules"

# Host bestimmen: explizit gesetzt, sonst aus der Umgebung erraten.
host="${JARVIS_HOST:-}"
if [ -z "$host" ]; then
  case "$(uname -s)" in
    Darwin) host=mac ;;
    Linux)  [ -f /.dockerenv ] && host=container || host=poseidon ;;
    *)      host=unbekannt ;;
  esac
fi

# Ein bestehender Symlink an dieser Stelle stammt aus dem alten Aufbau, in dem
# ~/.claude/rules direkt ins Repo zeigte. Er muss weg, sonst schreibt der
# nächste Schritt in die Dotfiles.
if [ -L "$RULES" ]; then rm "$RULES"; fi
mkdir -p "$RULES" "$RULES/local"

ln -sfn "$DOTFILES/claude/rules" "$RULES/shared"

if [ -d "$DOTFILES/claude/hosts/$host/rules" ]; then
  ln -sfn "$DOTFILES/claude/hosts/$host/rules" "$RULES/host"
else
  rm -f "$RULES/host"
  echo "Hinweis: keine host-spezifischen Regeln für '$host' vorhanden."
fi

# Lokales bleibt lokal: nie ins Repo, nie auf einen anderen Rechner.
cat > "$RULES/local/.gitignore" <<'IGN'
*
!.gitignore
IGN

echo "Regeln verknüpft (Host: $host):"
ls -l "$RULES" | tail -n +2

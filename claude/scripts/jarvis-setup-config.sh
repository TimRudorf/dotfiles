#!/usr/bin/env bash
# Richtet Claude-Konfiguration auf diesem Rechner ein. Idempotent, überall
# gleich: Mac, jarvis-Container, Poseidon.
#
# Zwei Schritte, weil sie verschiedene Werkzeuge brauchen:
#
#   1. stow verlinkt das Paket claude/.claude/ nach ~/.claude/.
#      Weil ~/.claude/ schon existiert (Anmeldedaten, Sitzungen), verlinkt
#      stow die Einträge einzeln statt des ganzen Verzeichnisses — genau
#      richtig, denn nur ein Teil davon gehört ins Repo.
#
#   2. Die Regeln kann stow nicht: ~/.claude/rules/ muss ein ECHTES
#      Verzeichnis sein, damit geteilte, host-spezifische und lokale Regeln
#      nebeneinander liegen können. Das macht jarvis-link-rules.sh.
set -euo pipefail

DOTFILES="${DOTFILES_DIR:-$HOME/dotfiles}"
cd "$DOTFILES"

command -v stow >/dev/null || { echo "stow fehlt — bitte installieren." >&2; exit 1; }

# Alte handverlinkte Symlinks entfernen, sonst bricht stow mit einem Konflikt
# ab. Nur solche, die ins Repo zeigen — fremde Dateien bleiben unangetastet.
for f in CLAUDE.md PERSONA.md PERSONALITY.md PROFILE.md settings.json skills; do
  t="$HOME/.claude/$f"
  if [ -L "$t" ] && [[ "$(readlink "$t")" == *"/dotfiles/claude/"* ]]; then
    rm "$t"
  fi
done

stow --restow --target="$HOME" claude
echo "stow: claude -> ~/.claude/"

"$DOTFILES/claude/scripts/jarvis-link-rules.sh"

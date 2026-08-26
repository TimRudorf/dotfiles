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
# ab. Erfasst wird das Muster, nicht eine Namensliste: jeder Symlink direkt in
# ~/.claude/, der irgendwo ins dotfiles-Repo zeigt, stammt aus dem alten
# Handbetrieb — auch tote, die nach einer Umbenennung zurueckblieben
# (CONTEXTS.md, PERSONA.md). Eine Aufzaehlung wuerde beim naechsten Umbenennen
# wieder unvollstaendig.
find "$HOME/.claude" -maxdepth 1 -type l -print0 2>/dev/null | while IFS= read -r -d "" t; do
  case "$(readlink "$t")" in
    */dotfiles/claude/*) rm "$t" ;;
  esac
done

stow --restow --target="$HOME" claude
echo "stow: claude -> ~/.claude/"

"$DOTFILES/claude/scripts/jarvis-link-rules.sh"

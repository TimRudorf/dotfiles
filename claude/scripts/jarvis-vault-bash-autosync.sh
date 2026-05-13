#!/usr/bin/env bash
# PostToolUse-Hook für Bash: nach jedem Bash-Aufruf den jarvis-wiki-Vault auf
# uncommitted changes scannen und auto-committen+pushen. Notwendig, weil
# Bash-Operationen wie `rm`, `mv`, `mkdir`, etc. die Vault-Files verändern
# können, ohne dass der dateispezifische Write/Edit-Hook
# (jarvis-vault-autosync.sh) greift.
#
# Wird von ~/dotfiles/claude/settings.json als hooks.PostToolUse mit
# matcher "Bash" eingebunden. Läuft auf Mac und Container.
#
# Fail-safe: jeder Fehler -> exit 0, kein Output.

set -u

# --- Vault-Detection (host-abhängig) ---
VAULT_DIR=""
for candidate in "/workspace/wiki" "$HOME/Documents/jarvis-wiki"; do
  if [ -d "$candidate/.git" ]; then
    VAULT_DIR="$candidate"
    break
  fi
done
[ -z "$VAULT_DIR" ] && exit 0

# --- Host-Detection (für Commit-Message) ---
if [ "${JARVIS_HOST:-}" = "container" ] || [ -f /.dockerenv ]; then
  HOST="container"
else
  HOST="mac"
fi

# --- Git-Operationen (alles fail-safe) ---
{
  cd "$VAULT_DIR" || exit 0

  # Schnell-Check: gibt es überhaupt was zu committen?
  if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    exit 0
  fi

  # Alles stagen — modifications, deletions, neue files
  git add -A 2>/dev/null || exit 0

  # Nochmal prüfen falls .gitignore alles geschluckt hat
  if git diff --cached --quiet; then
    exit 0
  fi

  # Liste der betroffenen Files für Commit-Message
  AFFECTED=$(git diff --cached --name-only 2>/dev/null | head -3 | tr '\n' ' ' | sed 's/ $//')
  COUNT=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
  if [ "$COUNT" -le 3 ]; then
    MSG="vault: bash-autosync ${AFFECTED} (via ${HOST})"
  else
    MSG="vault: bash-autosync ${COUNT} files (${AFFECTED}…) (via ${HOST})"
  fi

  git commit -m "$MSG" --quiet 2>/dev/null || exit 0

  # Pull --rebase davor, falls Peer in der Zwischenzeit gepusht hat.
  git pull --rebase --autostash --quiet 2>/dev/null || true

  # Push asynchron im Hintergrund.
  ( git push origin main --quiet 2>/dev/null & disown ) || true
} >/dev/null 2>&1

exit 0

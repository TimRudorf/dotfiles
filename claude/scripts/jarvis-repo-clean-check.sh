#!/usr/bin/env bash
# Stop-Hook: prüft vor Session-Ende, ob in den drei Haupt-Repos
# (jarvis-wiki Vault, dotfiles, docker-compose) uncommitted Files liegen.
#
# - Vault: auto-commit + push (wie der Write-Hook)
# - dotfiles, docker-compose: nur warnen, weil main protected ist
#   (PR-Workflow notwendig — Hook kann nicht auto-pushen)
#
# Hooks bekommen ihr Output über stderr in den Transcript-View. Hier
# nutzen wir das, um Warnungen sichtbar zu machen.
#
# Fail-safe: jeder Fehler -> exit 0.

set -u

# --- Host-Detection ---
if [ "${JARVIS_HOST:-}" = "container" ] || [ -f /.dockerenv ]; then
  HOST="container"
else
  HOST="mac"
fi

# Wenn im Container: nur Vault prüfen (dotfiles/docker-compose-Klon liegt auf VM, nicht im Container).
if [ "$HOST" = "container" ]; then
  REPOS_TO_CHECK="vault"
else
  REPOS_TO_CHECK="vault dotfiles docker-compose"
fi

# --- Vault: auto-commit + push ---
check_vault() {
  local vault_dir=""
  for candidate in "/workspace/wiki" "$HOME/Documents/jarvis-wiki"; do
    if [ -d "$candidate/.git" ]; then
      vault_dir="$candidate"
      break
    fi
  done
  [ -z "$vault_dir" ] && return

  cd "$vault_dir" || return

  # Falls clean: nichts zu tun
  if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    return
  fi

  git add -A 2>/dev/null || return
  if git diff --cached --quiet; then
    return
  fi

  local affected count msg
  affected=$(git diff --cached --name-only 2>/dev/null | head -3 | tr '\n' ' ' | sed 's/ $//')
  count=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" -le 3 ]; then
    msg="vault: stop-hook autosync ${affected} (via ${HOST})"
  else
    msg="vault: stop-hook autosync ${count} files (${affected}…) (via ${HOST})"
  fi
  git commit -m "$msg" --quiet 2>/dev/null || return
  git pull --rebase --autostash --quiet 2>/dev/null || true
  ( git push origin main --quiet 2>/dev/null & disown ) || true

  echo "[repo-clean-check] vault: ${count} files auto-committed (${affected})" >&2
}

# --- Protected Repo: nur Warnung ---
check_protected_repo() {
  local repo_dir="$1"
  local repo_name="$2"

  [ -d "$repo_dir/.git" ] || return
  cd "$repo_dir" || return

  if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    return
  fi

  local dirty_count untracked_count branch
  dirty_count=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
  staged_count=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
  untracked_count=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  branch=$(git branch --show-current 2>/dev/null)

  {
    echo ""
    echo "⚠️  [repo-clean-check] ${repo_name} (branch ${branch:-?}) ist NICHT clean:"
    [ "$dirty_count" -gt 0 ]   && echo "   • ${dirty_count} modified"
    [ "$staged_count" -gt 0 ]  && echo "   • ${staged_count} staged"
    [ "$untracked_count" -gt 0 ] && echo "   • ${untracked_count} untracked"
    echo "   → vor Session-Ende klären (commit+push, branch+PR, oder .gitignore)."
    git status --short 2>/dev/null | head -8 | sed 's/^/     /'
    echo ""
  } >&2
}

# --- Main ---
for repo in $REPOS_TO_CHECK; do
  case "$repo" in
    vault)
      check_vault
      ;;
    dotfiles)
      check_protected_repo "$HOME/dotfiles" "dotfiles"
      ;;
    docker-compose)
      check_protected_repo "$HOME/docker-compose" "docker-compose"
      ;;
  esac
done

exit 0

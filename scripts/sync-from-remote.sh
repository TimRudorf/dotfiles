#!/usr/bin/env bash
# Idempotent: fetch dotfiles, fast-forward main, redecrypt env if secrets/env.sops
# changed, recreate jarvis stack if /opt/stacks/jarvis/.env actually changed.
# Designed to run from cron / launchd every couple of minutes — silent on no-op,
# logs to ~/.cache/dotfiles-sync.log on activity.

set -euo pipefail

REPO="$HOME/dotfiles"
LOG="$HOME/.cache/dotfiles-sync.log"
mkdir -p "$(dirname "$LOG")"

log() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$LOG"; }

cd "$REPO"

# Cross-platform lock (mkdir is atomic on POSIX); auto-cleanup on exit
LOCK="$HOME/.cache/dotfiles-sync.lock.d"
if ! mkdir "$LOCK" 2>/dev/null; then
  # Stale lock if older than 10 min — clean and retry
  if find "$LOCK" -maxdepth 0 -mmin +10 2>/dev/null | grep -q .; then
    rm -rf "$LOCK" && mkdir "$LOCK" || exit 0
  else
    exit 0
  fi
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

git fetch --quiet origin main || { log "fetch failed"; exit 0; }

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)
[[ "$LOCAL" == "$REMOTE" ]] && exit 0

# Anything in the incoming range that we care about?
CHANGED=$(git diff --name-only "$LOCAL..$REMOTE")
log "behind by $(git rev-list --count "$LOCAL..$REMOTE") commit(s); changed: $(echo "$CHANGED" | tr '\n' ' ')"

if ! git pull --ff-only --quiet; then
  log "pull --ff-only failed (diverged or dirty tree?) — skipping"
  exit 0
fi

# Only decrypt if the encrypted env actually changed
if echo "$CHANGED" | grep -qx 'secrets/env.sops'; then
  case "$(uname)" in
    Darwin)
      TARGET="$HOME/.env"
      RESTART_FLAG=""
      ;;
    Linux)
      if [[ -d /opt/stacks/jarvis ]]; then
        TARGET="/opt/stacks/jarvis/.env"
        RESTART_FLAG="--restart-jarvis"
      else
        TARGET="$HOME/.env"
        RESTART_FLAG=""
      fi
      ;;
    *)
      log "unsupported OS $(uname)"
      exit 0
      ;;
  esac

  # Snapshot before so we can detect a real value change vs. just a sops re-key
  PRE_HASH=""
  [[ -f "$TARGET" ]] && PRE_HASH=$(shasum -a 256 "$TARGET" | awk '{print $1}')

  if [[ -n "$RESTART_FLAG" ]]; then
    # On VM: only restart compose if the decrypted file actually differs
    "$REPO/scripts/decrypt-env.sh" >> "$LOG" 2>&1 || { log "decrypt failed"; exit 0; }
    POST_HASH=$(shasum -a 256 "$TARGET" | awk '{print $1}')
    if [[ "$PRE_HASH" != "$POST_HASH" ]]; then
      log "env values changed — recreating jarvis stack"
      cd /opt/stacks/jarvis && docker compose up -d >> "$LOG" 2>&1
    else
      log "env file rewritten but values unchanged — skip restart"
    fi
  else
    "$REPO/scripts/decrypt-env.sh" >> "$LOG" 2>&1 || { log "decrypt failed"; exit 0; }
    log "decrypted to $TARGET"
  fi
fi

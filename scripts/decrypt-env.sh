#!/usr/bin/env bash
# Decrypt secrets/env.sops to ~/.env (Mac) or /opt/stacks/jarvis/.env (VM/Linux).
# Usage: scripts/decrypt-env.sh [--restart-jarvis]
#   --restart-jarvis : after writing /opt/stacks/jarvis/.env, run docker compose up -d jarvis-workspace

set -euo pipefail

# Cron strips PATH down to /usr/bin:/bin — make sops findable wherever it lives
# (apt → /usr/bin, GitHub release → /usr/local/bin, go/manual → ~/.local/bin).
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

if ! command -v sops >/dev/null 2>&1; then
  echo "sops not found on PATH ($PATH) — install via apt, GitHub release, or place in ~/.local/bin" >&2
  exit 5
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOPS_FILE="$REPO_ROOT/secrets/env.sops"

# Pick target by host
case "$(uname)" in
  Darwin)
    TARGET="$HOME/.env"
    ;;
  Linux)
    if [[ -d /opt/stacks/jarvis ]]; then
      TARGET="/opt/stacks/jarvis/.env"
    else
      TARGET="$HOME/.env"
    fi
    ;;
  *)
    echo "unsupported OS: $(uname)" >&2
    exit 1
    ;;
esac

# Locate age key — sops fails silently otherwise
KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
if [[ ! -r "$KEY_FILE" ]]; then
  echo "age key not found at $KEY_FILE — set SOPS_AGE_KEY_FILE or place key there" >&2
  exit 2
fi
export SOPS_AGE_KEY_FILE="$KEY_FILE"

if [[ ! -r "$SOPS_FILE" ]]; then
  echo "no encrypted file at $SOPS_FILE" >&2
  exit 3
fi

# Atomic write: tmp → mode 0600 → mv
TMP="$(mktemp "${TARGET}.XXXXXX")"
trap 'rm -f "$TMP"' EXIT
chmod 600 "$TMP"
sops --input-type=dotenv --output-type=dotenv -d "$SOPS_FILE" > "$TMP"
mv "$TMP" "$TARGET"
trap - EXIT
chmod 600 "$TARGET"

echo "decrypted → $TARGET ($(wc -c < "$TARGET") bytes)"

if [[ "${1:-}" == "--restart-jarvis" ]]; then
  if [[ "$TARGET" != "/opt/stacks/jarvis/.env" ]]; then
    echo "--restart-jarvis only valid when target is /opt/stacks/jarvis/.env" >&2
    exit 4
  fi
  cd /opt/stacks/jarvis
  docker compose up -d
  echo "jarvis stack recreated with new env (all services)"
fi

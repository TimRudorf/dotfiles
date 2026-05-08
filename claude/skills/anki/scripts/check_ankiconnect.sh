#!/usr/bin/env bash
# Smoke-Test für AnkiConnect.
# Exit 0 + "OK" wenn erreichbar, sonst Exit 1 + Diagnose.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/anki_call.sh"

if version=$(anki_call version 2>/dev/null) && [ "$version" = "6" ]; then
  echo "OK"
  exit 0
fi

echo "ERROR: AnkiConnect nicht erreichbar auf ${ANKI_HOST:-http://localhost:8765}." >&2
echo "Bitte Anki Desktop am Mac öffnen und ggf. AnkiConnect Add-on (Code 2055492159) prüfen." >&2
exit 1

#!/usr/bin/env bash
# Legt alle 12 Modul-Decks via createDeck an (idempotent).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/anki_call.sh"

for slug in "${ALL_SLUGS[@]}"; do
  deck=$(slug_to_deck "$slug")
  params=$(jq -n --arg d "$deck" '{deck: $d}')
  anki_call createDeck "$params" >/dev/null
  echo "✓ $deck"
done

echo ""
echo "12 Decks bereit."

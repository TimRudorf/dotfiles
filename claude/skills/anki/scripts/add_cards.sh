#!/usr/bin/env bash
# Legt Karten ins angegebene Deck. Idempotent für das Deck (createDeck), aber Karten-Duplikate werden geprüft.
# Usage: add_cards.sh <deck-name> <karten-json-file>
# Karten-JSON: array of {modelName, fields, tags}. modelName muss "Cloze" oder "Basic" sein.

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <deck-name> <karten-json-file>" >&2
  exit 2
fi

DECK="$1"
KARTEN_FILE="$2"

if [ ! -f "$KARTEN_FILE" ]; then
  echo "ERROR: Karten-Datei '$KARTEN_FILE' nicht gefunden." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/anki_call.sh"

# Deck idempotent anlegen
deck_params=$(jq -n --arg d "$DECK" '{deck: $d}')
anki_call createDeck "$deck_params" >/dev/null

# Karten-JSON in addNotes-Format umbauen: deckName + options einfügen
notes=$(jq --arg deck "$DECK" '
  map({
    deckName: $deck,
    modelName: .modelName,
    fields: .fields,
    tags: (.tags // []),
    options: {
      allowDuplicate: false,
      duplicateScope: "deck"
    }
  })
' "$KARTEN_FILE")

count=$(echo "$notes" | jq 'length')

if [ "$count" -eq 0 ]; then
  echo "Keine Karten zum Schreiben."
  exit 0
fi

params=$(jq -n --argjson n "$notes" '{notes: $n}')
result=$(anki_call addNotes "$params")

# addNotes liefert Array von Note-IDs (oder null pro Karte bei Duplikat-Reject)
added=$(echo "$result" | jq '[.[] | select(. != null)] | length')
skipped=$((count - added))

echo "$added Karten in '$DECK' angelegt."
if [ "$skipped" -gt 0 ]; then
  echo "$skipped Karten als Duplikat übersprungen."
fi

# Deck-Config normalisieren: jedes flache Modul-Deck auf eigenem Preset, kein Uni-Deck auf "Default".
# Pattern: tim/feedback/anki-deck-config-pattern. Idempotent.
NORMALIZE="$HOME/Documents/jarvis-wiki/projekte/lernplan/anki-deck-config.py"
if [[ "$DECK" == Uni::* ]] && [ -f "$NORMALIZE" ]; then
  echo ""
  python3 "$NORMALIZE" | tail -1
fi

#!/usr/bin/env bash
# Zieht Anki-Stats pro Modul-Deck via AnkiConnect und schreibt Snapshot ins Vault.
# Usage: snapshot.sh [modul-slug]   (ohne Arg → alle 12 Module)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/anki_call.sh"

VAULT="${VAULT:-$HOME/Documents/jarvis-wiki}"
[ -d "$VAULT" ] || { echo "ERROR: Vault unter $VAULT nicht gefunden." >&2; exit 1; }

OUTFILE="$VAULT/projekte/lernplan/anki-stats.md"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE_ONLY=$(date +"%Y-%m-%d")

# Welche Slugs?
if [ "$#" -ge 1 ]; then
  SLUGS=("$1")
else
  SLUGS=("${ALL_SLUGS[@]}")
fi

stats_for_deck() {
  local deck="$1"

  # Total
  local total_query=$(jq -n --arg q "deck:\"$deck\"" '{query: $q}')
  local total_ids=$(anki_call findCards "$total_query")
  local total=$(echo "$total_ids" | jq 'length')

  if [ "$total" -eq 0 ]; then
    echo "0|0|0|0|0|0|0|0"
    return
  fi

  # Due today
  local due_today_query=$(jq -n --arg q "deck:\"$deck\" is:due" '{query: $q}')
  local due_today=$(anki_call findCards "$due_today_query" | jq 'length')

  # Due in next 7 days
  local due_week_query=$(jq -n --arg q "deck:\"$deck\" prop:due<=7" '{query: $q}')
  local due_week=$(anki_call findCards "$due_week_query" | jq 'length')

  # Mature (interval >= 21 days)
  local mature_query=$(jq -n --arg q "deck:\"$deck\" prop:ivl>=21" '{query: $q}')
  local mature=$(anki_call findCards "$mature_query" | jq 'length')

  # Young (lerned but not mature)
  local young_query=$(jq -n --arg q "deck:\"$deck\" -is:new prop:ivl<21" '{query: $q}')
  local young=$(anki_call findCards "$young_query" | jq 'length')

  # New (never reviewed)
  local new_query=$(jq -n --arg q "deck:\"$deck\" is:new" '{query: $q}')
  local new=$(anki_call findCards "$new_query" | jq 'length')

  # Lapses sum (sample to keep it bounded — use cardsInfo of first 200 cards)
  local sample_ids=$(echo "$total_ids" | jq '.[0:500]')
  local sample_params=$(jq -n --argjson c "$sample_ids" '{cards: $c}')
  local lapses_total=0
  if [ "$(echo "$sample_ids" | jq 'length')" -gt 0 ]; then
    lapses_total=$(anki_call cardsInfo "$sample_params" | jq '[.[].lapses] | add // 0')
  fi

  local mature_pct=0
  if [ "$total" -gt 0 ]; then
    mature_pct=$(awk "BEGIN { printf \"%.0f\", ($mature / $total) * 100 }")
  fi

  echo "$total|$due_today|$due_week|$mature|$young|$new|$lapses_total|$mature_pct"
}

# Markdown-Tabelle aufbauen
{
  cat <<EOF
---
title: Anki-Stats — Snapshot
type: projekt
tags:
  - uni
  - lernplan
  - anki
description: Stats-Snapshot aller Modul-Decks via AnkiConnect — Quelle für Druck-Score-Erweiterung im Heartbeat (siehe [[projekte/lernplan/cross-modul#Anki-Penalty]]).
created: $DATE_ONLY
updated: $DATE_ONLY
status: aktiv
last_snapshot: $TIMESTAMP
---

> [!info] Snapshot-Mechanik
> Diese Note wird vom \`/anki status\`-Skill geschrieben. Heartbeat liest sie für Druck-Score-Berechnung. Snapshot-Alter >36 h → Heartbeat triggert Notification an Tim. Konzept: [[projekte/lernplan/anki-konzept#Stats-Snapshot-Mechanik]].

## Stand $TIMESTAMP

| Modul | Deck | Total | Due heute | Due Woche | Mature % | Young | Neu | Lapses (sample) |
|---|---|---:|---:|---:|---:|---:|---:|---:|
EOF

  for slug in "${SLUGS[@]}"; do
    deck=$(slug_to_deck "$slug")
    stats=$(stats_for_deck "$deck")
    IFS='|' read -r total due_today due_week mature young new lapses mature_pct <<< "$stats"
    echo "| $slug | \`$deck\` | $total | $due_today | $due_week | ${mature_pct}% | $young | $new | $lapses |"
  done

  cat <<EOF

## true_retention_30d

\`null\` — AnkiConnect liefert keine direkte Retrievability. Manuell aus FSRS Helper Add-on (Anki Desktop → Tools → Stats → True Retention) ablesen und unten ergänzen, falls für Druck-Score-Berechnung benötigt.

| Modul | true_retention_30d |
|---|---:|
EOF
  for slug in "${SLUGS[@]}"; do
    echo "| $slug | _null_ |"
  done

} > "$OUTFILE"

echo "Snapshot geschrieben: $OUTFILE"
echo ""
echo "Top-3 Module nach Due heute:"
for slug in "${SLUGS[@]}"; do
  deck=$(slug_to_deck "$slug")
  due_today_query=$(jq -n --arg q "deck:\"$deck\" is:due" '{query: $q}')
  due=$(anki_call findCards "$due_today_query" | jq 'length')
  echo "$due $slug"
done | sort -rn | head -3

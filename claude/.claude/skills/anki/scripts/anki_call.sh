#!/usr/bin/env bash
# Generic AnkiConnect helper.
# Usage: anki_call <action> [json-params]
# Returns: jq-parsed result, or non-zero exit + error message on failure.

set -euo pipefail

ANKI_HOST="${ANKI_HOST:-http://localhost:8765}"

anki_call() {
  local action="$1"
  local params="${2:-}"
  [ -z "$params" ] && params='{}'
  local payload
  payload=$(jq -nc --arg a "$action" --argjson p "$params" \
    '{action: $a, version: 6, params: $p}')

  local response
  response=$(curl -s -m 10 -X POST -d "$payload" "$ANKI_HOST")

  if [ -z "$response" ]; then
    echo "ERROR: AnkiConnect liefert leere Antwort. Anki Desktop offen?" >&2
    return 1
  fi

  local err
  err=$(echo "$response" | jq -r '.error // empty')
  if [ -n "$err" ]; then
    echo "ERROR: AnkiConnect — $err" >&2
    return 1
  fi

  echo "$response" | jq '.result'
}

# Modul-Slug → Anki-Deck Mapping
slug_to_deck() {
  case "$1" in
    dimm)                     echo "Uni::DIMM" ;;
    ppm-seminar)              echo "Uni::PPM-Seminar" ;;
    entrepreneurial)          echo "Uni::Entrepreneurial" ;;
    modern-firm)              echo "Uni::Modern-Firm" ;;
    international-economics)  echo "Uni::International-Economics" ;;
    rvcps)                    echo "Uni::RVCPS" ;;
    mldl-auto)                echo "Uni::ML-DL-Auto" ;;
    praktikum-rt2)            echo "Uni::Praktikum-RT2" ;;
    sdrt3)                    echo "Uni::SDRT3" ;;
    sensortechnik)            echo "Uni::Sensortechnik" ;;
    thermo)                   echo "Uni::Thermo" ;;
    mpc-ml)                   echo "Uni::MPC-ML" ;;
    *) echo "ERROR: Unbekannter Modul-Slug '$1'" >&2; return 1 ;;
  esac
}

ALL_SLUGS=(
  dimm ppm-seminar entrepreneurial modern-firm international-economics
  rvcps mldl-auto praktikum-rt2 sdrt3 sensortechnik thermo mpc-ml
)

# Make functions available when sourced
export -f anki_call slug_to_deck 2>/dev/null || true

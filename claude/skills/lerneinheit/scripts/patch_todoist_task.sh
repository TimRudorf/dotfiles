#!/usr/bin/env bash
# patch_todoist_task.sh <modul-slug> <thema-slug> <vault-pfad-relativ>
#
# Sucht heute's Todoist-Task, dessen Content zum Modul + Thema passt,
# und patcht die Description mit einem obsidian://-Deeplink zur Lerneinheit-Note.
# Idempotent — Link wird nur hinzugefügt, wenn er noch nicht drinsteht.
#
# Exit codes:
#   0 = Task gefunden + gepatcht (oder Link war schon drin)
#   2 = Kein passender Task gefunden (Warning, kein Fail)
#   1 = Hard error (Token fehlt, API-Fehler, …)

set -euo pipefail

MODUL_SLUG="${1:?Usage: $0 <modul-slug> <thema-slug> <vault-pfad-relativ>}"
THEMA_SLUG="${2:?Usage: $0 <modul-slug> <thema-slug> <vault-pfad-relativ>}"
VAULT_PATH="${3:?Usage: $0 <modul-slug> <thema-slug> <vault-pfad-relativ>}"

if [[ -z "${TODOIST_API_TOKEN:-}" ]]; then
  if [[ -f "$HOME/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$HOME/.env"
    set +a
  fi
fi

if [[ -z "${TODOIST_API_TOKEN:-}" ]]; then
  echo "ERROR: TODOIST_API_TOKEN nicht gesetzt (weder in env noch in ~/.env)" >&2
  exit 1
fi

# Modul-Slug → Kürzel + Emoji für Content-Match
case "$MODUL_SLUG" in
  dimm)                    KUERZEL="DIM"; EMOJI="📈" ;;
  ppm-seminar)             KUERZEL="PPM"; EMOJI="📝" ;;
  entrepreneurial)         KUERZEL="ES";  EMOJI="💼" ;;
  modern-firm)             KUERZEL="MF";  EMOJI="🏛" ;;
  international-economics) KUERZEL="IntEco"; EMOJI="🌍" ;;
  rvcps)                   KUERZEL="CPS"; EMOJI="📐" ;;
  mldl-auto)               KUERZEL="ML"; EMOJI="🤖" ;;
  praktikum-rt2)           KUERZEL="P-RT2"; EMOJI="⚙️" ;;
  sdrt3)                   KUERZEL="SDRT3"; EMOJI="🔁" ;;
  sensortechnik)           KUERZEL="ST"; EMOJI="📡" ;;
  thermo)                  KUERZEL="Thermo"; EMOJI="🔬" ;;
  mpc-ml)                  KUERZEL="MPC"; EMOJI="🎛" ;;
  *)
    echo "ERROR: unbekannter modul-slug: $MODUL_SLUG" >&2
    exit 1
    ;;
esac

# URL-encode den Vault-Pfad (Pfade mit / und Sonderzeichen)
URL_ENCODED_PATH=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$VAULT_PATH")
OBSIDIAN_URL="obsidian://open?vault=jarvis-wiki&file=${URL_ENCODED_PATH}"
LINK_LINE="🔗 Lerneinheit-Brief: ${OBSIDIAN_URL}"

# Heute's Tasks holen
TASKS_JSON=$(curl -fsS -X GET "https://api.todoist.com/api/v1/tasks/filter?query=today" \
  -H "Authorization: Bearer $TODOIST_API_TOKEN")

# Task suchen, der Modul-Kürzel/Emoji UND mindestens einen Thema-Token enthält
# Tokenisierung passiert in Python — vermeidet Bash-3.2-Quirks mit Process Substitution
MATCH_ID=$(python3 - "$TASKS_JSON" "$KUERZEL" "$EMOJI" "$THEMA_SLUG" <<'PY'
import json, sys, re
tasks_json, kuerzel, emoji, thema_slug = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
thema_tokens = [t.lower() for t in re.split(r'[-_]+', thema_slug) if len(t) >= 3]

data = json.loads(tasks_json)
tasks = data.get('results', data) if isinstance(data, dict) else data

best_id = None
best_score = 0
for t in tasks:
    content = (t.get('content') or '').lower()
    has_modul = (kuerzel.lower() in content) or (emoji in (t.get('content') or ''))
    if not has_modul:
        continue
    score = sum(1 for tok in thema_tokens if tok in content)
    if score > best_score:
        best_score = score
        best_id = t.get('id')

# Mindestens 1 Token-Match nötig — sonst zu unspezifisch
if best_score >= 1:
    print(best_id or '')
PY
)

if [[ -z "$MATCH_ID" ]]; then
  echo "WARN: kein passender Todoist-Task heute gefunden (modul=$MODUL_SLUG, thema=$THEMA_SLUG)" >&2
  exit 2
fi

# Aktuelle Description laden
TASK_JSON=$(curl -fsS -X GET "https://api.todoist.com/api/v1/tasks/$MATCH_ID" \
  -H "Authorization: Bearer $TODOIST_API_TOKEN")
CUR_DESC=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('description') or '')" "$TASK_JSON")
CUR_CONTENT=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('content') or '')" "$TASK_JSON")

# Idempotenz: wenn der Obsidian-URL-Link schon drin steht, nichts tun
if echo "$CUR_DESC" | grep -qF "$OBSIDIAN_URL"; then
  echo "OK (no-op): Lerneinheit-Brief-Link steht schon in Description von Task '$CUR_CONTENT'"
  exit 0
fi

# Neue Description: bestehende + 2 Newlines + Link-Zeile
if [[ -n "$CUR_DESC" ]]; then
  NEW_DESC="${CUR_DESC}"$'\n\n'"${LINK_LINE}"
else
  NEW_DESC="$LINK_LINE"
fi

# Patch
PAYLOAD=$(python3 -c "import json,sys; print(json.dumps({'description': sys.argv[1]}))" "$NEW_DESC")
curl -fsS -X POST "https://api.todoist.com/api/v1/tasks/$MATCH_ID" \
  -H "Authorization: Bearer $TODOIST_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" >/dev/null

echo "OK: Task '$CUR_CONTENT' (id=$MATCH_ID) Description um Lerneinheit-Brief-Link erweitert"
exit 0

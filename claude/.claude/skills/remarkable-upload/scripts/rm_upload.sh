#!/usr/bin/env bash
# reMarkable Simple Upload
# Uploads a PDF/EPUB to reMarkable Cloud via the Simple Upload API.
# Usage: rm_upload.sh <file-path> [folder-id]
#
# Requires: RM_DEVICE_TOKEN env var
# Uses: internal.cloud.remarkable.com/doc/v2/files (same as Chrome extension "Read on reMarkable")

set -euo pipefail

FILE="$1"
FOLDER_ID="${2:-}"

if [ ! -f "$FILE" ]; then
  echo '{"success":false,"error":"Datei nicht gefunden: '"$FILE"'"}'
  exit 1
fi

# Detect content type
EXT="${FILE##*.}"
EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
case "$EXT_LOWER" in
  pdf)  CONTENT_TYPE="application/pdf" ;;
  epub) CONTENT_TYPE="application/epub+zip" ;;
  *)    echo '{"success":false,"error":"Nur PDF und EPUB unterstuetzt, nicht: .'"$EXT_LOWER"'"}'; exit 1 ;;
esac

# File name without extension
BASENAME=$(basename "$FILE" ".$EXT")

if [ -z "${RM_DEVICE_TOKEN:-}" ]; then
  echo '{"success":false,"error":"RM_DEVICE_TOKEN nicht gesetzt"}'
  exit 1
fi

# Step 1: Get user token
USER_TOKEN=$(curl -s -X POST \
  "https://webapp-prod.cloud.remarkable.engineering/token/json/2/user/new" \
  -H "Authorization: Bearer $RM_DEVICE_TOKEN")

if [ -z "$USER_TOKEN" ] || echo "$USER_TOKEN" | grep -qi "error\|unauthorized"; then
  echo '{"success":false,"error":"Auth fehlgeschlagen — Device Token ungueltig?","details":"'"$USER_TOKEN"'"}'
  exit 1
fi

# Step 2: Build rm-meta header (base64-encoded JSON)
if [ -n "$FOLDER_ID" ]; then
  META_JSON="{\"file_name\":\"$BASENAME\",\"parent\":\"$FOLDER_ID\"}"
else
  META_JSON="{\"file_name\":\"$BASENAME\"}"
fi
RM_META=$(echo -n "$META_JSON" | base64 -w0)

# Step 3: Upload
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "https://internal.cloud.remarkable.com/doc/v2/files" \
  -H "Authorization: Bearer $USER_TOKEN" \
  -H "Content-Type: $CONTENT_TYPE" \
  -H "rm-meta: $RM_META" \
  -H "rm-source: RoR-Browser" \
  --data-binary @"$FILE")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
  DOC_ID=$(echo "$BODY" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('docID',''))" 2>/dev/null || echo "")
  echo "{\"success\":true,\"docID\":\"$DOC_ID\",\"fileName\":\"$BASENAME.$EXT_LOWER\",\"httpCode\":$HTTP_CODE}"
else
  echo "{\"success\":false,\"error\":\"HTTP $HTTP_CODE\",\"body\":$(echo "$BODY" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))' 2>/dev/null || echo '""')}"
  exit 1
fi

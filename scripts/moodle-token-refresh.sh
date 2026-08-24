#!/usr/bin/env bash
# Moodle-Webservice-Token auf beiden Hosts erneuern (Mac + Container).
#
# Hintergrund: Der TU-Token laeuft etwa quartalsweise ab; ein Auto-Refresh ueber
# Shibboleth-SSO ist nicht praktikabel, der Browser-Schritt bleibt Handarbeit.
# Alles danach macht dieses Skript: pruefen, auf beide Hosts schreiben (die
# Token-Dateien haben je Host ein ANDERES Schema), zurueckglesen, verifizieren.
#
# Der Token wird verdeckt eingelesen und niemals ausgegeben oder geloggt.
#
# Aufruf:  scripts/moodle-token-refresh.sh
set -euo pipefail

DOMAIN="moodle.tu-darmstadt.de"
MAC_TOKEN_FILE="$HOME/.config/moodle-dl/token.tim.json"
VM_SSH="jarvis-vm"
CONTAINER="jarvis-workspace"
CONTAINER_TOKEN_FILE="/workspace/moodle/token.json"

die() { printf '\n\033[31mFEHLER:\033[0m %s\n' "$1" >&2; exit 1; }
ok()  { printf '\033[32m  OK\033[0m  %s\n' "$1"; }

cat <<EOF

Moodle-Token erneuern
=====================
1. Im Browser bei Moodle per SSO einloggen, dann oeffnen:
     https://$DOMAIN/user/managetoken.php
   Dort den Token des Dienstes "Moodle mobile web service" kopieren.

2. Falls die Seite keinen Token zeigt, Fallback ueber den Launch-Blob:
     https://$DOMAIN/admin/tool/mobile/launch.php?service=moodle_mobile_app&passport=1&urlscheme=moodledl
   Der Redirect lautet moodledl://token=<base64>. Diesen ganzen Wert hier
   einfuegen -- das Skript dekodiert ihn selbst.

EOF

printf 'Token oder Launch-Blob (Eingabe bleibt unsichtbar): '
read -rs RAW
printf '\n\n'
[ -n "$RAW" ] || die "Keine Eingabe erhalten."

# Launch-Blob entpacken: moodledl://token=<base64> -> pubkey:::TOKEN:::privatetoken
TOKEN="$(RAW="$RAW" python3 - <<'PY'
import base64, os, re, sys
raw = os.environ["RAW"].strip()
m = re.search(r'token=([A-Za-z0-9+/=_-]+)', raw)
blob = m.group(1) if m else raw
# Ein reiner WS-Token ist 32 Hex-Zeichen und wird unveraendert durchgereicht.
if re.fullmatch(r'[0-9a-f]{32}', blob):
    print(blob); sys.exit()
try:
    pad = blob + "=" * (-len(blob) % 4)
    parts = base64.b64decode(pad.replace('-', '+').replace('_', '/')).decode().split(':::')
except Exception as exc:
    sys.exit(f"Eingabe ist weder ein 32-stelliger Token noch ein dekodierbarer Launch-Blob ({exc}).")
if len(parts) < 2:
    sys.exit("Launch-Blob hat nicht das erwartete Format pubkey:::TOKEN:::privatetoken.")
print(parts[1])
PY
)" || die "Eingabe konnte nicht ausgewertet werden (Details oben)."

# --- Vorab pruefen, bevor irgendetwas geschrieben wird -----------------------
printf 'Pruefe Token gegen %s ...\n' "$DOMAIN"
SITE="$(curl -sS --max-time 20 "https://$DOMAIN/webservice/rest/server.php" \
  -d "wstoken=$TOKEN" -d "wsfunction=core_webservice_get_site_info" \
  -d "moodlewsrestformat=json")" || die "Moodle nicht erreichbar."
USER_INFO="$(SITE="$SITE" python3 - <<'PY'
import json, os, sys
d = json.loads(os.environ["SITE"])
if d.get("errorcode"):
    sys.exit(f'Moodle lehnt den Token ab: {d["errorcode"]} -- Schritt 1/2 oben wiederholen.')
print(f'{d.get("username","?")} ({d.get("fullname","?")})')
PY
)" || die "Token ungueltig -- es wurde nichts geschrieben."
ok "Token gueltig fuer $USER_INFO"

# --- Mac: {domain, token} ----------------------------------------------------
mkdir -p "$(dirname "$MAC_TOKEN_FILE")"
[ -f "$MAC_TOKEN_FILE" ] && cp -p "$MAC_TOKEN_FILE" "$MAC_TOKEN_FILE.bak"
umask 077
DOMAIN="$DOMAIN" TOKEN="$TOKEN" OUT="$MAC_TOKEN_FILE" python3 - <<'PY'
import json, os
json.dump({"domain": os.environ["DOMAIN"], "token": os.environ["TOKEN"]},
          open(os.environ["OUT"], "w"), indent=2)
PY
chmod 600 "$MAC_TOKEN_FILE"
ok "Mac geschrieben: $MAC_TOKEN_FILE"

# --- Container: {moodle_url, token} -- anderes Schema als auf dem Mac! -------
# Token geht ueber stdin, damit er nicht in der Prozessliste der VM auftaucht.
printf '%s' "$TOKEN" | ssh "$VM_SSH" "docker exec -i $CONTAINER python3 -c '
import json, os, shutil, sys
p = \"$CONTAINER_TOKEN_FILE\"
if os.path.exists(p): shutil.copy2(p, p + \".bak\")
os.makedirs(os.path.dirname(p), exist_ok=True)
json.dump({\"moodle_url\": \"https://$DOMAIN\", \"token\": sys.stdin.read().strip()}, open(p, \"w\"), indent=2)
os.chmod(p, 0o600)
'" || die "Schreiben im Container fehlgeschlagen -- Mac ist bereits aktuell, Container laeuft noch auf dem alten Token."
ok "Container geschrieben: $CONTAINER_TOKEN_FILE"

# --- Read-back: beide Hosts fragen mit dem GESCHRIEBENEN Token nach ----------
printf '\nVerifiziere Read-back ...\n'
MAC_OUT="$(python3 - "$MAC_TOKEN_FILE" <<'PY'
import json, sys, urllib.parse, urllib.request
c = json.load(open(sys.argv[1]))
q = urllib.parse.urlencode({"wstoken": c["token"], "wsfunction": "core_webservice_get_site_info",
                            "moodlewsrestformat": "json"}).encode()
d = json.load(urllib.request.urlopen(f'https://{c["domain"]}/webservice/rest/server.php', q, timeout=20))
sys.exit(f'Mac-Datei liefert {d["errorcode"]}') if d.get("errorcode") else print(d.get("username", "?"))
PY
)" || die "Read-back auf dem Mac fehlgeschlagen (Details oben)."
ok "Mac verifiziert (Nutzer $MAC_OUT)"

VM_OUT="$(ssh "$VM_SSH" "docker exec $CONTAINER python3 -c '
import json, sys, urllib.parse, urllib.request
c = json.load(open(\"$CONTAINER_TOKEN_FILE\"))
q = urllib.parse.urlencode({\"wstoken\": c[\"token\"], \"wsfunction\": \"core_webservice_get_site_info\",
                            \"moodlewsrestformat\": \"json\"}).encode()
d = json.load(urllib.request.urlopen(c[\"moodle_url\"] + \"/webservice/rest/server.php\", q, timeout=20))
sys.exit(\"Container-Datei liefert \" + d[\"errorcode\"]) if d.get(\"errorcode\") else print(d.get(\"username\", \"?\"))
'")" || die "Read-back im Container fehlgeschlagen (Details oben)."
ok "Container verifiziert (Nutzer $VM_OUT)"

cat <<EOF

Fertig -- beide Hosts tragen denselben gueltigen Token.
Naechster Schritt: der Heartbeat zieht das neue Material automatisch. Sofort
nachziehen geht mit dem Moodle-Sync (Vault des Hosts vorher auf origin/main
bringen, sonst gilt alles als neu):
  git -C ~/Documents/jarvis-wiki pull --ff-only
  python3 ~/dev/docker-compose/jarvis/jarvis-tasks/moodle_sync.py
EOF

# Create-Modus — Neues Ticket erstellen

Erstellt ein neues Zammad-Ticket und sendet die erste E-Mail an den Kunden.

## Schritt C1: Kunde in Zammad suchen

Organisation und zugehörige User suchen:

```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"

curl -s -H "Authorization: Token token=${ZAMMAD_TOKEN}" \
  "$BASE/api/v1/organizations/search?query={name}&limit=5" > /tmp/z_org_search.json \
  && jq '[.[] | {id, name, note}]' /tmp/z_org_search.json
```

Dann User der Organisation suchen (für E-Mail-Adresse):

```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"

curl -s -H "Authorization: Token token=${ZAMMAD_TOKEN}" \
  "$BASE/api/v1/users/search?query={name}&limit=10" > /tmp/z_user_search.json \
  && jq '[.[] | {id, firstname, lastname, email, organization_id}]' /tmp/z_user_search.json
```

- Gefunden → Kunden-ID + E-Mail verwenden
- Mehrere Treffer → User per `AskUserQuestion` auswählen lassen
- Nicht gefunden → User informieren + Abbruch

## Schritt C2: Titel ableiten

Aus dem Kontext einen kurzen, aussagekräftigen Ticket-Titel ableiten (z.B. "Bereitstellung Setup-Dateien", "Testlizenz für EDP").

## Schritt C3: Gruppe auswählen

Verfügbare Gruppen laden:

```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"

curl -s -H "Authorization: Token token=${ZAMMAD_TOKEN}" \
  "$BASE/api/v1/groups" > /tmp/z_groups.json \
  && jq '[.[] | select(.active == true) | {id, name}]' /tmp/z_groups.json
```

User per `AskUserQuestion` befragen. Default: "Entwicklung".

## Schritt C4: Besitzer ermitteln

Aktuellen User laden:

```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"

curl -s -H "Authorization: Token token=${ZAMMAD_TOKEN}" \
  "$BASE/api/v1/users/me" > /tmp/z_me.json \
  && jq '{id, firstname, lastname, email}' /tmp/z_me.json
```

Immer den aktuellen User als Owner setzen, außer im Kontext anders angegeben.

## Schritt C5: Status + Priorität

User per `AskUserQuestion` nach Status fragen. Default: `open`. Priorität: immer `2 normal` (priority_id: 2).

## Schritt C6: Signatur laden

Signatur der gewählten Gruppe laden (wie Reply-Modus Schritt 3):

```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"
GROUP_ID={group_id}

curl -s -H "Authorization: Token token=${ZAMMAD_TOKEN}" \
  "$BASE/api/v1/groups/$GROUP_ID" > /tmp/z_group.json \
  && SIG_ID=$(jq -r '.signature_id // empty' /tmp/z_group.json) \
  && if [ -n "$SIG_ID" ]; then \
    curl -s -H "Authorization: Token token=${ZAMMAD_TOKEN}" \
      "$BASE/api/v1/signatures/$SIG_ID" > /tmp/z_signature.json \
    && jq -r '.body // empty' /tmp/z_signature.json; \
  else \
    echo "NO_SIGNATURE"; \
  fi
```

## Schritt C7: E-Mail verfassen

Nachricht nach den gleichen Regeln wie Reply-Modus Schritt 5 verfassen:

- Sprache: Deutsch
- Ton: Professionell, höflich, freundlich
- HTML-Format mit `<div>`-Tags (kein `<p>`)
- Signatur am Ende anhängen

## Schritt C8: Human in the Loop

Entwurf per `AskUserQuestion` vorlegen:

```
Neues Ticket — Entwurf
━━━━━━━━━━━━━━━━━━━━━━
Titel:   {titel}
Kunde:   {customer_name} ({customer_email})
Gruppe:  {gruppe}
Owner:   {owner_name}
Status:  {status}

Nachricht:
──────
{antworttext}
──────
```

Options: **"Erstellen & Senden"**, **"Ändern"**, **"Abbrechen"**

## Schritt C9: Ticket erstellen

**WICHTIG — Body-Übergabe**: Gleiche Regeln wie Reply-Modus — Body per `--rawfile`, Payload per Temp-Datei.

```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"

cat > /tmp/z_body.html << 'BODY_EOF'
{nachricht_html_mit_signatur}
BODY_EOF

jq -n \
  --arg title "{titel}" \
  --argjson group_id {group_id} \
  --argjson customer_id {customer_id} \
  --argjson owner_id {owner_id} \
  --arg state "{status}" \
  --argjson priority_id 2 \
  --arg to "{customer_email}" \
  --arg subject "{titel}" \
  --rawfile body /tmp/z_body.html \
  '{
    title: $title,
    group_id: $group_id,
    customer_id: $customer_id,
    owner_id: $owner_id,
    state: $state,
    priority_id: $priority_id,
    article: {
      to: $to,
      subject: $subject,
      body: $body,
      content_type: "text/html",
      type: "email",
      internal: false,
      sender: "Agent"
    }
  }' > /tmp/z_ticket_payload.json

curl -s -X POST \
  -H "Authorization: Token token=${ZAMMAD_TOKEN}" \
  -H "Content-Type: application/json" \
  --data @/tmp/z_ticket_payload.json \
  "$BASE/api/v1/tickets" > /tmp/z_new_ticket.json \
  && jq '{id, number, title, state, group, customer_id, owner_id}' /tmp/z_new_ticket.json
```

## Schritt C10: Ergebnis anzeigen

Nach Erfolg anzeigen:
- Ticket-Nummer + URL (`{ZAMMAD_HOST}/#ticket/zoom/{ticket_id}`)
- Titel
- Kunde + E-Mail
- Gruppe
- Status

Bei Fehler: HTTP Status Code und Error Body anzeigen.

## Notes

Alle Notes aus der Haupt-SKILL.md gelten auch hier (Temp-Dateien, `source .env` pro Shell, `--rawfile`, etc.).

---
name: zammad-send
description: This skill should be used when the user asks to "reply to a customer", "answer a Zammad ticket", "send a response", "create a new ticket", "neues Ticket erstellen", "E-Mail an Kunden senden", or uses /zammad-send. It replies to existing tickets or creates new ones with auto-detected channel.
argument-hint: [ticket-number | customer-name] [options]
---

# Zammad Kundenantwort senden / Neues Ticket erstellen

Zwei Modi: **Reply-Modus** (auf bestehendes Ticket antworten) und **Create-Modus** (neues Ticket erstellen und E-Mail senden).

## Configuration

Environment variables from `~/Develop/EDP/.env`:

- `ZAMMAD_HOST` — Base URL of the Zammad instance
- `ZAMMAD_TOKEN` — API token for authentication

## Modus-Erkennung

Analysiere das erste Argument:

- **Zahl** oder `EDP#...` → **Reply-Modus** (bestehendes Ticket)
- **Alles andere** (Name, Organisation) → **Create-Modus** (neues Ticket)

## Parameters

### Reply-Modus

| Parameter | Required | Beschreibung |
|---|---|---|
| Ticketnummer | Ja | Zammad-Ticketnummer (z.B. `7620726` oder `EDP#7620726`) |
| Antwortform | Nein | `email` oder `web` — erzwingt den Antwortkanal |
| Status | Nein | Neuer Ticket-Status nach dem Senden |
| Context | Nein | Zusätzlicher Kontext / Anweisungen für die Antwort |

### Create-Modus

| Parameter | Required | Beschreibung |
|---|---|---|
| Kunde | Ja | Kundenname oder Organisationsname |
| Context | Ja | Inhalt / Anlass der E-Mail |

Für den vollständigen Create-Workflow siehe `create-mode.md` in diesem Skill-Verzeichnis.

## Reply-Modus Workflow

### Schritt 1: Ticket auslesen

Strip any `EDP#` prefix from the ticket number and resolve it:

```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"
AUTH="Authorization: Token token=${ZAMMAD_TOKEN}"

curl -s -H "$AUTH" "$BASE/api/v1/tickets/search?query=number:{number}" > /tmp/z_search.json \
  && jq '.[0] | {id, number, title}' /tmp/z_search.json
```

Then load ticket details and all articles:

```bash
TICKET_ID={ticket_id}

curl -s -H "$AUTH" "$BASE/api/v1/tickets/$TICKET_ID?expand=true" > /tmp/z_ticket.json \
  && curl -s -H "$AUTH" "$BASE/api/v1/ticket_articles/by_ticket/$TICKET_ID" > /tmp/z_articles.json \
  && echo "TICKET:" && jq '{number, title, state, priority, owner, group, group_id, customer, organization, created_at, updated_at}' /tmp/z_ticket.json \
  && echo "ARTICLES:" && jq -r '.[] | "---\nVon: \(.from // .created_by)\nDatum: \(.created_at)\nTyp: \(.type) (\(.sender))\nIntern: \(.internal)\nTo: \(.to // "n/a")\nInhalt: \(.body | gsub("<[^>]*>"; " ") | gsub("&gt;"; ">") | gsub("&lt;"; "<") | gsub("&amp;"; "&") | gsub("\\s+"; " ") | ltrimstr(" "))\n"' /tmp/z_articles.json
```

Always use `?expand=true` on the tickets endpoint for human-readable field values.

### Schritt 2: Kanal erkennen

**Falls der User den Parameter `Antwortform` übergeben hat** (`email` oder `web`), diesen direkt verwenden — die automatische Erkennung überspringen.

**Andernfalls** den letzten Artikel mit `sender: "Customer"` finden und dessen `type` prüfen:

```bash
jq '[.[] | select(.sender == "Customer")] | last | {type, from, to}' /tmp/z_articles.json
```

| Quelle | Antwort-Typ | Erklärung |
|---|---|---|
| User übergibt `email` ODER Kunden-Artikel `type` ist nicht `web` | `type: "email"`, `internal: false` | E-Mail-Antwort an den Kunden |
| User übergibt `web` ODER Kunden-Artikel `type` ist `web` | `type: "note"`, `internal: false` | Öffentlicher Kommentar im Web-Portal |

Determine the customer's email address from the last Customer article's `from` field (or from the ticket's `customer` field). For email replies, this is the `to` address.

### Schritt 3: Signatur laden (nur bei E-Mail)

Only for email replies — load the group's signature:

```bash
GROUP_ID=$(jq -r '.group_id' /tmp/z_ticket.json)
curl -s -H "$AUTH" "$BASE/api/v1/groups/$GROUP_ID" > /tmp/z_group.json \
  && SIG_ID=$(jq -r '.signature_id // empty' /tmp/z_group.json) \
  && if [ -n "$SIG_ID" ]; then \
    curl -s -H "$AUTH" "$BASE/api/v1/signatures/$SIG_ID" > /tmp/z_signature.json \
    && jq -r '.body // empty' /tmp/z_signature.json; \
  else \
    echo "NO_SIGNATURE"; \
  fi
```

If the signature cannot be loaded (missing permissions, no signature configured): proceed without signature.

### Schritt 4: Status auflösen (falls übergeben)

If the user provided a desired new status, load available states and match:

```bash
curl -s -H "$AUTH" "$BASE/api/v1/ticket_states" > /tmp/z_states.json \
  && jq '[.[] | select(.active == true) | .name]' /tmp/z_states.json
```

Match the user's input against the server states:
- "schließen" / "closed" → `closed`
- "offen" → `open`
- "warten auf schließen" / "pending close" → `pending close` (erfordert `pending_time`, Standard: +7 Tage)
- "warten" / "pending reminder" → `pending reminder` (erfordert `pending_time`)

If no unambiguous match is found, ask the user in the confirmation dialog.

If no status was provided: skip this step — Schritt 10 wird den User am Ende fragen.

### Schritt 5: Antwort verfassen

Analyze the full conversation history and optional user context, then compose a reply:

- **Sprache**: Deutsch
- **Ton**: Professionell, höflich, freundlich
- **Kein Hinweis** auf AI oder automatische Erstellung — die Antwort muss wie von einem menschlichen Mitarbeiter klingen
- **Echte Umlaute** verwenden (ä, ö, ü, ß)
- **HTML-Format (Web und E-Mail)**: Immer `content_type: "text/html"`. Zammad verwendet NICHT `<p>`-Tags — diese werden ohne Abstand gerendert. Stattdessen Zammad-natives Format verwenden:
  - Jede Textzeile in `<div>...</div>` wrappen
  - Leerzeile/Absatz: `<div><br></div>`
  - Beispiel: `<div>Hallo Herr Prinz,</div><div><br></div><div>Vielen Dank...</div>`
  - Nach der Anrede: `<div><br></div>`
  - Vor der Grußformel: `<div><br></div>`
  - Grußformel und Name in separaten `<div>`-Tags (ohne `<br>` dazwischen)
- **E-Mail-Antworten**: Signatur am Ende anhängen (nach `<div><br></div>`)
- **Web-Antworten**: Keine Signatur

### Schritt 6: Human in the Loop

Present the draft via `AskUserQuestion`:

```
Antwort-Entwurf (Ticket #{nummer})
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Ticket:  #{nummer} — {titel}
Kunde:   {customer}
Kanal:   {E-Mail | Web-Portal}
An:      {empfänger} (nur bei E-Mail)
Status:  {aktuell} → {neu} (nur wenn Status-Änderung)

Nachricht:
──────
{antworttext}
──────
```

Options: **"Absenden"**, **"Ändern"**, **"Als Entwurf speichern"**, **"Abbrechen"**

- If "Ändern": Ask the user what to change, revise, and present again.
- If "Abbrechen": Stop without sending.
- If "Als Entwurf speichern": Proceed to Schritt 7 (Shared Draft).
- If "Absenden": Proceed to Schritt 8 (Artikel erstellen).

### Schritt 7: Shared Draft speichern (optional)

If the user chose "Als Entwurf speichern", save the reply as a Shared Draft via `PUT /api/v1/tickets/{ticket_id}/shared_draft`. The draft will be visible in the Zammad WebUI under the ticket.

```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"
TICKET_ID={ticket_id}
FORM_ID=$(date +%s%N | head -c 12)

cat > /tmp/z_body.html << 'BODY_EOF'
{antwort_html_mit_signatur}
BODY_EOF

jq -n \
  --arg form_id "$FORM_ID" \
  --rawfile body /tmp/z_body.html \
  --argjson ticket_id $TICKET_ID \
  --arg to "{customer_email}" \
  --arg from "{agent_name}" \
  '{
    form_id: $form_id,
    new_article: {
      body: $body,
      cc: "",
      content_type: "text/html",
      from: $from,
      in_reply_to: "",
      internal: false,
      sender_id: 1,
      subject: "",
      subtype: "",
      ticket_id: $ticket_id,
      to: $to,
      type: "email",
      type_id: 1
    },
    ticket_attributes: {}
  }' > /tmp/z_draft_payload.json

curl -s -w "\nHTTP_CODE:%{http_code}" \
  -X PUT \
  -H "Authorization: Token token=${ZAMMAD_TOKEN}" \
  -H "Content-Type: application/json" \
  --data @/tmp/z_draft_payload.json \
  "$BASE/api/v1/tickets/$TICKET_ID/shared_draft" > /tmp/z_draft.json
```

On success (HTTP 200): display the Shared Draft ID and inform the user that the draft is available in the Zammad WebUI. Then stop — do NOT proceed to Schritt 8.

On error: show HTTP status code and error body.

### Schritt 8: Artikel erstellen

After confirmation, send the article via API.

**WICHTIG — Body-Übergabe an jq**: Niemals den Nachrichtentext direkt als `--arg` an jq übergeben — `jq --arg` behandelt `\n` als literale Zeichen, nicht als Zeilenumbrüche. Stattdessen:

1. Body-HTML in eine Temp-Datei schreiben (mit Heredoc für echte Zeilenumbrüche)
2. Mit `jq --rawfile body /tmp/z_body.html` einlesen
3. JSON-Payload in Temp-Datei schreiben, dann `curl --data @datei` verwenden

**E-Mail:**
```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"
TICKET_ID={ticket_id}

cat > /tmp/z_body.html << 'BODY_EOF'
{antwort_html_mit_signatur}
BODY_EOF

jq -n \
  --argjson tid $TICKET_ID \
  --arg to "{customer_email}" \
  --arg subject "{ticket_subject}" \
  --rawfile body /tmp/z_body.html \
  '{ticket_id: $tid, to: $to, subject: $subject, body: $body, content_type: "text/html", type: "email", internal: false, sender: "Agent"}' \
  > /tmp/z_payload.json

curl -s -X POST \
  -H "Authorization: Token token=${ZAMMAD_TOKEN}" \
  -H "Content-Type: application/json" \
  --data @/tmp/z_payload.json \
  "$BASE/api/v1/ticket_articles" > /tmp/z_send_article.json \
  && jq '{id, ticket_id, type, to, created_at}' /tmp/z_send_article.json
```

**Web:**
```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"
TICKET_ID={ticket_id}

cat > /tmp/z_body.html << 'BODY_EOF'
{antwort_html}
BODY_EOF

jq -n \
  --argjson tid $TICKET_ID \
  --rawfile body /tmp/z_body.html \
  '{ticket_id: $tid, body: $body, content_type: "text/html", type: "note", internal: false, sender: "Agent"}' \
  > /tmp/z_payload.json

curl -s -X POST \
  -H "Authorization: Token token=${ZAMMAD_TOKEN}" \
  -H "Content-Type: application/json" \
  --data @/tmp/z_payload.json \
  "$BASE/api/v1/ticket_articles" > /tmp/z_send_article.json \
  && jq '{id, ticket_id, type, created_at}' /tmp/z_send_article.json
```

### Schritt 9: Ticket-Status setzen (optional)

If a status was resolved in Schritt 4, update the ticket. Ansonsten weiter zu Schritt 10.

**Einfacher Status** (z.B. `closed`, `open`):
```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"
TICKET_ID={ticket_id}

jq -n --arg state "{exakter_status_name}" '{state: $state}' > /tmp/z_state_payload.json

curl -s -X PUT \
  -H "Authorization: Token token=${ZAMMAD_TOKEN}" \
  -H "Content-Type: application/json" \
  --data @/tmp/z_state_payload.json \
  "$BASE/api/v1/tickets/$TICKET_ID" > /tmp/z_ticket_update.json \
  && jq '{id, number, state}' /tmp/z_ticket_update.json
```

**Pending-Status** (`pending close` oder `pending reminder`) — diese erfordern zusätzlich ein `pending_time` (ISO 8601 Zeitstempel), ab dem die Aktion ausgelöst wird:
```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"
TICKET_ID={ticket_id}

jq -n \
  --arg state "pending close" \
  --arg pending "{ISO_8601_TIMESTAMP}" \
  '{state: $state, pending_time: $pending}' > /tmp/z_state_payload.json

curl -s -X PUT \
  -H "Authorization: Token token=${ZAMMAD_TOKEN}" \
  -H "Content-Type: application/json" \
  --data @/tmp/z_state_payload.json \
  "$BASE/api/v1/tickets/$TICKET_ID" > /tmp/z_ticket_update.json \
  && jq '{id, number, state, pending_time}' /tmp/z_ticket_update.json
```

Typische Zeiträume: 1 Woche (`+7 Tage`), 2 Wochen (`+14 Tage`), 1 Monat (`+30 Tage`).

### Schritt 10: "Warten auf Schließen" anbieten

**Falls kein Status vom User übergeben wurde UND das Ticket noch nicht auf `pending close` oder `closed` steht**, den User fragen, ob das Ticket auf "Warten auf Schließen" gestellt werden soll.

Per `AskUserQuestion`:

```
Soll das Ticket auf "Warten auf Schließen" (1 Woche) gestellt werden?
```

Options: **"Ja, 1 Woche"**, **"Nein, Status beibehalten"**

- If "Ja, 1 Woche": Status auf `pending close` setzen mit `pending_time` = heute + 7 Tage (siehe Schritt 9).
- If "Nein": Status nicht ändern.

### Schritt 11: Ergebnis anzeigen

After success, display:
- Article-ID
- Ticket-Nummer
- Kanal (E-Mail / Web-Portal)
- Neuer Status (falls geändert), bei `pending close` auch das Datum anzeigen

On error: show HTTP status code and error body.

## Notes

- **Jeder Bash-Aufruf ist eine eigene Shell** — Variablen wie `$AUTH`, `$BASE`, `$TICKET_ID` gehen zwischen Tool-Aufrufen verloren. Jeder Schritt muss `source ~/Develop/EDP/.env` und die nötigen Variablen neu setzen.
- **Auth-Header immer inline** — Nicht `$AUTH` als Variable speichern und an curl übergeben. Stattdessen direkt: `-H "Authorization: Token token=${ZAMMAD_TOKEN}"`. Die Variable mit Leerzeichen kann sonst beim Piping an curl zu `blank argument` Fehlern führen.
- **Body niemals per `jq --arg`** — `jq --arg body "text\nmehr"` escapet `\n` als literale Zeichen (`\\n`), was zu fehlender Formatierung führt. Stattdessen: Body in Temp-Datei schreiben (Heredoc), dann `jq --rawfile body /tmp/z_body.html` verwenden.
- **Payload immer über Temp-Datei** — JSON-Payload erst in Datei schreiben (`> /tmp/z_payload.json`), dann `curl --data @/tmp/z_payload.json`. Nicht per Pipe (`| curl ... --data @-`), da dies bei Variablen-Problemen silent fails verursacht.
- Always save curl output to temp files first, then process with `jq`. Direct piping can silently produce empty output.
- The trailing slash in `ZAMMAD_HOST` is stripped with `${ZAMMAD_HOST%/}` to avoid double slashes.
- Always use `jq -n` with `--arg` / `--argjson` to construct JSON payloads for simple string values. For multiline content (message bodies), use `--rawfile` instead.
- If a request fails, show the HTTP status code and error message to the user.
- For E-Mail replies, the `to` field must contain the customer's email address, and `subject` should match the ticket subject.

---

## Skill-Optimierung

Nach Abschluss dieses Skills kurz bewerten, ob Optimierungsbedarf besteht:

- **Empfehlung "ja"**: Fehler aufgetreten, Workarounds nötig, Befehle wiederholt, User-Korrekturen
- **Empfehlung "nein"**: Reibungsloser Lauf wie dokumentiert

Per `AskUserQuestion` fragen:

> Skill abgeschlossen. Soll die Skill-Dokumentation optimiert werden?
> Empfehlung: {ja — [kurzer Grund] | nein — Lauf war reibungslos}

Optionen: **"Ja, optimieren"**, **"Nein"**

Bei "Ja": `skill-optimize` mit Skill-Name `zammad-send` ausführen.

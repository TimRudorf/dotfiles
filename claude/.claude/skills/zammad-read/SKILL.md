---
name: zammad-read
description: This skill should be used when the user asks to "read a Zammad ticket", "show ticket details", "look up EDP# ticket", or when another skill needs to fetch Zammad ticket data.
user-invocable: false
---

# Zammad Ticket lesen

Zeigt ein Zammad-Ticket mit allen Artikeln an.

## Configuration

Environment variables from `~/.env`:

- `ZAMMAD_HOST` — Base URL of the Zammad instance
- `ZAMMAD_TOKEN` — API token for authentication

## Resolving Ticket Number → ID

Users typically provide a **ticket number** (e.g. `7620726` or `EDP#7620726`). Strip any `EDP#` prefix and search:

```bash
source ~/.env
BASE="${ZAMMAD_HOST%/}"
AUTH="Authorization: Token token=${ZAMMAD_TOKEN}"

curl -s -H "$AUTH" "$BASE/api/v1/tickets/search?query=number:{number}" > /tmp/z_search.json \
  && jq '.[0].id' /tmp/z_search.json
```

If the user provides a numeric ticket ID directly, skip the search.

## Reading a Ticket

Run both requests in a **single bash command** and save to temp files (piping curl directly to jq can produce empty output):

```bash
source ~/.env
BASE="${ZAMMAD_HOST%/}"
AUTH="Authorization: Token token=${ZAMMAD_TOKEN}"
TICKET_ID={ticket_id}

curl -s -H "$AUTH" "$BASE/api/v1/tickets/$TICKET_ID?expand=true" > /tmp/z_ticket.json \
  && curl -s -H "$AUTH" "$BASE/api/v1/ticket_articles/by_ticket/$TICKET_ID" > /tmp/z_articles.json \
  && echo "TICKET:" && jq '{number, title, state, priority, owner, group, organization, customer, created_at, updated_at}' /tmp/z_ticket.json \
  && echo "ARTICLES:" && jq -r '.[] | "---\nVon: \(.from // .created_by)\nDatum: \(.created_at)\nTyp: \(.type) (\(.sender))\nIntern: \(.internal)\nInhalt: \(.body | gsub("<[^>]*>"; " ") | gsub("&gt;"; ">") | gsub("&lt;"; "<") | gsub("&amp;"; "&") | gsub("\\s+"; " ") | ltrimstr(" "))\n"' /tmp/z_articles.json
```

### Important: `?expand=true`

Always use `?expand=true` on the tickets endpoint. This makes the API return human-readable names instead of numeric IDs:

| Field          | Without expand | With expand              |
|----------------|---------------|--------------------------|
| `state`        | (missing)     | `"new"`                  |
| `priority`     | (missing)     | `"2 normal"`             |
| `owner`        | (missing)     | `"user@example.com"`     |
| `group`        | (missing)     | `"Entwicklung"`          |
| `organization` | (missing)     | `"Org Name"`             |
| `customer`     | (missing)     | `"customer@example.com"` |

The `_id` fields are still present alongside the resolved string fields.

Note: The articles endpoint already returns `type` and `sender` as strings without `expand`.

## Output Format

Present the ticket as a markdown table followed by articles:

**Ticket #`number` — `title`**

| Feld | Wert |
|---|---|
| **Status** | `state` |
| **Prioritaet** | `priority` |
| **Zugewiesen an** | `owner` |
| **Gruppe** | `group` |
| **Organisation** | `organization` |
| **Kunde** | `customer` |
| **Erstellt** | `created_at` (date only) |
| **Aktualisiert** | `updated_at` (date only) |

Then list each article with: sender (`from`), date, type/sender-role, internal flag, and body content (HTML stripped).

## Notes

- Always save curl output to temp files first, then process with `jq`. Direct piping can silently produce empty output.
- The trailing slash in `ZAMMAD_HOST` is stripped with `${ZAMMAD_HOST%/}` to avoid double slashes.
- If a request fails, show the HTTP status code and error message to the user.

---

## Skill-Optimierung

Nach Abschluss dieses Skills kurz bewerten, ob Optimierungsbedarf besteht:

- **Empfehlung "ja"**: Fehler aufgetreten, Workarounds nötig, Befehle wiederholt, User-Korrekturen
- **Empfehlung "nein"**: Reibungsloser Lauf wie dokumentiert

Per `AskUserQuestion` fragen:

> Skill abgeschlossen. Soll die Skill-Dokumentation optimiert werden?
> Empfehlung: {ja — [kurzer Grund] | nein — Lauf war reibungslos}

Optionen: **"Ja, optimieren"**, **"Nein"**

Bei "Ja": `skill-optimize` mit Skill-Name `zammad-read` ausführen.

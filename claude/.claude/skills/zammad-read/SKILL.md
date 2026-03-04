---
name: zammad-read
description: This skill should be used when the user asks to "read a Zammad ticket", "show ticket details", "look up EDP# ticket", or when another skill needs to fetch Zammad ticket data.
user-invocable: false
---

# Zammad Ticket lesen

Zeigt ein Zammad-Ticket mit allen Artikeln an.

## Voraussetzungen
- Env: `ZAMMAD_HOST`, `ZAMMAD_TOKEN`
- Tools: `curl`, `jq`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Resolving Ticket Number → ID

Users typically provide a **ticket number** (e.g. `7620726` or `EDP#7620726`). Strip any `EDP#` prefix and search:

```bash
BASE="${ZAMMAD_HOST%/}"
AUTH="Authorization: Token token=${ZAMMAD_TOKEN}"

curl -s -H "$AUTH" "$BASE/api/v1/tickets/search?query=number:{number}" > /tmp/z_search.json \
  && jq '.[0].id' /tmp/z_search.json
```

If the user provides a numeric ticket ID directly, skip the search.

## Reading a Ticket

Run both requests in a **single bash command** and save to temp files (piping curl directly to jq can produce empty output):

```bash
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

## Output

Stelle das Ticket übersichtlich dar — Ticketnummer, Titel, Status, Priorität, Zuständiger, Gruppe, Organisation, Kunde, Erstell-/Aktualisierungsdatum. Danach die Artikel chronologisch: Absender, Datum, Typ, intern/öffentlich, Inhalt. Wähle das Darstellungsformat frei (Tabelle, Liste, etc.) — Hauptsache klar und gut lesbar.

## Notes

- Always save curl output to temp files first, then process with `jq`. Direct piping can silently produce empty output.
- The trailing slash in `ZAMMAD_HOST` is stripped with `${ZAMMAD_HOST%/}` to avoid double slashes.
- If a request fails, show the HTTP status code and error message to the user.

Abschließend `skill-optimize` mit `zammad-read` aufrufen.

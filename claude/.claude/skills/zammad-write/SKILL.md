# Zammad Kommentar schreiben

Schreibt einen Kommentar (Article) in ein Zammad-Ticket.

## Configuration

Environment variables from `~/.claude/.env`:

- `ZAMMAD_BASE_URL` — Base URL of the Zammad instance
- `ZAMMAD_TOKEN` — API token for authentication

## Resolving Ticket Number → ID

Users typically provide a **ticket number** (e.g. `7620726` or `EDP#7620726`). Strip any `EDP#` prefix and search:

```bash
source ~/.claude/.env
BASE="${ZAMMAD_BASE_URL%/}"
AUTH="Authorization: Token token=${ZAMMAD_TOKEN}"

curl -s -H "$AUTH" "$BASE/api/v1/tickets/search?query=number:{number}" > /tmp/z_search.json \
  && jq '.[0] | {id, number, title}' /tmp/z_search.json
```

If the user provides a numeric ticket ID directly, skip the search.

## Creating the Article

Use `jq -n` to build the JSON payload safely (handles quotes, special chars, multiline text):

```bash
source ~/.claude/.env
BASE="${ZAMMAD_BASE_URL%/}"
AUTH="Authorization: Token token=${ZAMMAD_TOKEN}"

BODY="{comment_text}"

jq -n \
  --argjson tid {ticket_id} \
  --arg body "$BODY" \
  --argjson internal {true_or_false} \
  '{ticket_id: $tid, body: $body, content_type: "text/plain", type: "note", internal: $internal, sender: "Agent"}' \
| curl -s -X POST \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  --data @- \
  "$BASE/api/v1/ticket_articles" > /tmp/z_article.json \
  && jq '{id, ticket_id, internal, body, created_at, created_by}' /tmp/z_article.json
```

## Parameters

| Field | Required | Description |
|---|---|---|
| `ticket_id` | Yes | Numeric ticket ID (resolve from number if needed) |
| `body` | Yes | Comment text. Plain text or HTML (match `content_type`) |
| `content_type` | Yes | `"text/plain"` or `"text/html"` |
| `type` | Yes | `"note"` for comments. Other values: `"phone"`, `"email"` |
| `internal` | No | `true` = only visible to agents, `false` = visible to customer. **Default: `true`** |
| `sender` | Yes | `"Agent"` |
| `subject` | No | Optional subject line |
| `time_unit` | No | Time spent (e.g. `"15"` for 15 minutes) |

## Behavior

- **Default to internal** (`"internal": true`) unless the user explicitly asks for a customer-visible / public comment.
- Before posting, **confirm with the user** using `AskUserQuestion`:
  - Show the ticket number + title
  - Show the comment text
  - Show whether it will be internal or public
  - Options: "Absenden", "Ändern", "Abbrechen"
- After successful creation, display: Article-ID, Ticket-Nummer, intern/öffentlich, and the body.
- If the request fails, show the HTTP status and error body.

## Notes

- Always save curl output to temp files first, then process with `jq`. Direct piping can silently produce empty output.
- The trailing slash in `ZAMMAD_BASE_URL` is stripped with `${ZAMMAD_BASE_URL%/}` to avoid double slashes.
- Always use `jq -n` with `--arg` / `--argjson` to construct JSON payloads. Never interpolate variables directly into JSON strings — this avoids escaping issues with quotes, newlines, and special characters.
- If a request fails, show the HTTP status code and error message to the user.

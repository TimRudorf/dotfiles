---
name: zammad-write
description: This skill should be used when the user asks to "write a comment on a Zammad ticket", "add a note to a ticket", or when another skill needs to post an article to a Zammad ticket.
user-invocable: false
---

# Zammad Kommentar schreiben

Schreibt einen Kommentar (Article) in ein Zammad-Ticket.

## Configuration

Environment variables from `~/Develop/EDP/.env`:

- `ZAMMAD_HOST` — Base URL of the Zammad instance
- `ZAMMAD_TOKEN` — API token for authentication

## Resolving Ticket Number → ID

Users typically provide a **ticket number** (e.g. `7620726` or `EDP#7620726`). Strip any `EDP#` prefix and search:

```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"
AUTH="Authorization: Token token=${ZAMMAD_TOKEN}"

curl -s -H "$AUTH" "$BASE/api/v1/tickets/search?query=number:{number}" > /tmp/z_search.json \
  && jq '.[0] | {id, number, title}' /tmp/z_search.json
```

If the user provides a numeric ticket ID directly, skip the search.

## Creating the Article (Internal Notes)

For **internal notes** (short body, no attachments), use `jq -n` to build the JSON payload:

```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"
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

## Sending Emails (type: "email")

**Always use Python for email articles.** Multiline bodies with signatures and special characters (Umlaute) cause `jq --arg` to fail silently in piped shell commands.

### Step 1: Look up customer email and signature (bash)

These read-only lookups can use bash/curl:

```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"
AUTH="Authorization: Token token=${ZAMMAD_TOKEN}"

# Get customer_id from ticket
curl -s -H "$AUTH" "$BASE/api/v1/tickets/{ticket_id}" > /tmp/z_ticket.json \
  && jq '{id, number, title, customer_id}' /tmp/z_ticket.json

# Get customer email (use Python for control chars)
curl -s -H "$AUTH" "$BASE/api/v1/users/{customer_id}" > /tmp/z_user.json
python3 -c "
import json
with open('/tmp/z_user.json') as f:
    d = json.loads(f.read(), strict=False)
print(d['email'])
"

# Get signature template + agent data (parallel calls)
curl -s -H "$AUTH" "$BASE/api/v1/signatures/2" > /tmp/z_sig.json \
  && jq '{id, name, body}' /tmp/z_sig.json
curl -s -H "$AUTH" "$BASE/api/v1/users/me" > /tmp/z_me.json \
  && jq '{firstname, lastname, email, funktion}' /tmp/z_me.json
```

### Step 2: Resolve signature

The Zammad API does **not** auto-append signatures (unlike the UI). For outgoing emails:

1. Get the signature template: `GET /api/v1/signatures/2` (default: "EDP Standardsignatur")
2. Get the agent's user data: `GET /api/v1/users/me`
3. Replace template variables: `#{user.firstname}`, `#{user.lastname}`, `#{user.email}`, `#{user.funktion}`
4. Strip HTML tags from the signature body (it's HTML) and convert to plain text
5. Append the resolved signature to the article body **before** sending

### Step 3: Send email via Python

```python
import json, os, urllib.request, urllib.error

env = {}
with open(os.path.expanduser("~/Develop/EDP/.env")) as f:
    for line in f:
        line = line.strip()
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip().strip('"').strip("'")

base_url = env["ZAMMAD_HOST"].rstrip("/")
token = env["ZAMMAD_TOKEN"]

body = """Message text here...

--
Resolved signature here..."""

payload = {
    "ticket_id": TICKET_ID,
    "body": body,
    "content_type": "text/plain",
    "type": "email",
    "to": "customer@example.com",
    "internal": False,
    "sender": "Agent"
}

req = urllib.request.Request(
    f"{base_url}/api/v1/ticket_articles",
    data=json.dumps(payload).encode("utf-8"),
    headers={
        "Authorization": f"Token token={token}",
        "Content-Type": "application/json"
    },
    method="POST"
)

try:
    with urllib.request.urlopen(req) as resp:
        result = json.loads(resp.read().decode("utf-8"), strict=False)
        print(json.dumps({
            "id": result["id"],
            "ticket_id": result["ticket_id"],
            "internal": result["internal"],
            "created_at": result["created_at"]
        }, indent=2))
except urllib.error.HTTPError as e:
    print(f"HTTP {e.code}: {e.read().decode()}")
```

**Important**: Email article bodies cannot be edited after creation via the API.

## Attachments

For articles with file attachments, use Python instead of jq/curl — base64-encoded files easily exceed shell argument limits.

```python
import json, base64, os, urllib.request, urllib.error

env = {}
with open(os.path.expanduser("~/Develop/EDP/.env")) as f:
    for line in f:
        line = line.strip()
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip().strip('"').strip("'")

base_url = env["ZAMMAD_HOST"].rstrip("/")
token = env["ZAMMAD_TOKEN"]

# Base64-encode each file
attachments = []
for path, name in [("/path/to/file.png", "file.png")]:
    with open(path, "rb") as f:
        data = base64.b64encode(f.read()).decode()
    attachments.append({"filename": name, "data": data, "mime-type": "image/png"})

payload = {
    "ticket_id": TICKET_ID,
    "body": "...",
    "content_type": "text/plain",
    "type": "note",  # or "email" (with "to" field)
    "internal": True,
    "sender": "Agent",
    "attachments": attachments
}

req = urllib.request.Request(
    f"{base_url}/api/v1/ticket_articles",
    data=json.dumps(payload).encode(),
    headers={
        "Authorization": f"Token token={token}",
        "Content-Type": "application/json"
    },
    method="POST"
)

with urllib.request.urlopen(req) as resp:
    result = json.loads(resp.read())
    print(f"Article-ID: {result['id']}")
```

## Parameters

| Field | Required | Description |
|---|---|---|
| `ticket_id` | Yes | Numeric ticket ID (resolve from number if needed) |
| `body` | Yes | Comment text. Plain text or HTML (match `content_type`) |
| `content_type` | Yes | `"text/plain"` or `"text/html"` |
| `type` | Yes | `"note"` for comments. Other values: `"phone"`, `"email"` |
| `to` | If email | **Required for `type: "email"`**. Recipient address. Look up via `/api/v1/users/{customer_id}` from ticket |
| `internal` | No | `true` = only visible to agents, `false` = visible to customer. **Default: `true`** |
| `sender` | Yes | `"Agent"` |
| `subject` | No | Optional subject line |
| `time_unit` | No | Time spent (e.g. `"15"` for 15 minutes) |
| `attachments` | No | Array of `{filename, data (base64), "mime-type"}` objects |

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
- The trailing slash in `ZAMMAD_HOST` is stripped with `${ZAMMAD_HOST%/}` to avoid double slashes.
- For internal notes (short body, no attachments): `jq -n` with `--arg` / `--argjson` is sufficient.
- **For email articles**: Always use Python (`urllib.request`) — multiline bodies with signatures and special characters (Umlaute) cause `jq --arg` to fail silently in piped shell commands.
- **For articles with attachments**: use Python (`urllib.request`) instead of jq/curl — base64 data exceeds shell argument limits.
- Zammad user API responses may contain control characters — use `json.loads(data, strict=False)` in Python.
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

Bei "Ja": `skill-optimize` mit Skill-Name `zammad-write` ausführen.

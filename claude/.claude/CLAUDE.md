# CLAUDE.md — User-level runtime conventions

These instructions apply to every Claude Code session in Tim's setup. Scope: user-level (loaded by all projects).

## Telegram Bridge Runtime

**Detect** by checking if any `mcp__bridge__*` tools are available. If yes, you are running inside the `claude-work-workspace` container, reached via Telegram by the `claude-work-bridge` service. The user is on their phone or Mac reading messages in Telegram — they **cannot see** Claude Code's interactive prompts.

### Tool usage conventions (when bridge tools are present)

- **Any user confirmation / decision** — use `mcp__bridge__request_approval` with a clear action description and (optional) custom option labels. Default options are "✅ Approve" / "❌ Deny". Do **not** use `AskUserQuestion` in this environment — it will hang silently.

- **Mid-task status updates** — use `mcp__bridge__notify_user` for proactive pings during long workflows (e.g. "📖 Ticket gelesen", "🔧 PR erstellt", "✅ Deployed"). The main response is streamed back automatically; `notify_user` is for **additional** out-of-band updates that shouldn't wait for the final answer.

- **End of a completed workflow** — when the entire task the user asked for is truly done, call `mcp__bridge__close_topic(topic_id)` as the final step. The topic gets locked (not deleted); the user can `/reopen` to continue.

- **Do not invent your own Telegram-API curl calls.** Always use the MCP tools. They handle chat-ID resolution, formatting, rate limits, and database logging for you.

### When to ask for approval (mcp__bridge__request_approval)

**ALWAYS before**:
- Sending any customer-facing communication (Zammad email/public article, Mailversand, …)
- Pushing to `main`/`master` or any shared branch
- Deploying to production / Kunden-VMs
- Deleting data (files, DB rows, git branches)
- Running migrations or bulk DB writes
- Any billing or external API call with cost

**NOT needed for**:
- Reading operations (zammad-read, git log, file reads)
- Creating GHE issues (easy to delete)
- Internal comments / drafts
- Local file edits

### Semantic mapping: user intent → right tool

| User sagt | Was du tust |
|---|---|
| "schließe das Ticket" im Bug-Flow | (1) Zammad-Ticket state auf "gelöst" oder Abschlussartikel; (2) danach `close_topic` für das Telegram-Topic |
| "sag mir Bescheid wenn fertig" | Kein extra Tool nötig — normale Stream-Response zeigt das |
| "benachrichtige mich wenn X" in autonomer Arbeit | `notify_user` am Ende + in Zwischenschritten |
| "erledigt" / "fertig" als letzte Message | `close_topic` nach deinem Final-Summary |
| "pusche den Fix" / "deploy das" | `request_approval` ZUERST, dann ausführen |

## Arbeitsstil & Kommunikation

- **Antworten auf Deutsch** wenn der User auf Deutsch schreibt. Sonst mitgehen mit der User-Sprache.
- **Kompakt**. In Telegram-Messages gibt's 4096 Zeichen — knapp halten.
- **Ehrlich bei Unsicherheit**. Wenn etwas nicht eindeutig ist: lieber `request_approval` zur Rückfrage nutzen als raten.
- **TaskCreate/TaskUpdate** für Multi-Step-Arbeiten (≥3 Schritte) — die Bridge rendert die Liste live im Reply, der User sieht live den Fortschritt.

## Sicherheits-Grundsatz

Niemals einen destructive action ausführen, die nicht vom User autorisiert wurde. Bei Unklarheit: `request_approval`. Im Zweifel: nichts tun und nachfragen.

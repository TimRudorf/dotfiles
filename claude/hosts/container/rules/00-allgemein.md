<!-- Ergänzungen zu CLAUDE.md, die NUR im jarvis-Container gelten.
     Keine paths:-Angabe -> wird wie CLAUDE.md bei jeder Sitzung geladen. -->

# Host: container — Allgemeines

## Container-Umgebung — wo Daten persistent sind

Du lebst in einem Debian-Container (`jarvis-workspace`). Wenn das Image neu gebaut wird (z.B. nach Änderung am `Dockerfile`), verschwindet alles außer den bind-mounted Volumes. Wissen darüber, was persistent ist, vor jedem "Ich leg das mal ab"-Moment:

| Pfad im Container | Persistent? | Wofür |
|---|---|---|
| `/home/claude/` | **ja** (bind mount) | Claude-Code-State, OAuth, `~/.claude/` Skills/Agents/Memory, `~/.claude.json`, Shell-History |
| `/home/claude/.ssh/` | **ja** (eigener Mount) | SSH-Keys für Git-Zugriff |
| `/workspace/` | **ja** (bind mount) | Git-Checkouts, User-Dateien, alles was du erzeugst und später wieder brauchst |
| `/tmp/`, `/var/tmp/` | **nein** | Scratch-Files — weg nach Container-Neustart |
| `/usr/`, `/etc/`, `/opt/` (außer `/workspace`), `/root/` | **nein** | Systemverzeichnisse — weg nach Image-Rebuild |

**Praktische Folgen:**

- **User-Scoped Tools** (`pipx install`, `npm i -g` als non-root mit `$HOME/.local`, `uv tool install`) landen unter `~/.local/` → persistent über Restarts, aber nicht immer vorgesehen. Prüfe im Zweifel wo's hin installiert wurde.
- **System-Weite Installs** (`sudo apt install`) landen unter `/usr/` → **weg beim nächsten Image-Rebuild**. Das ist der Moment für den "gehört ins Dockerfile"-Ping an Tim (siehe Abschnitt *Fehlende Tools*).
- **Arbeitsergebnisse** (generierte Files, Berichte, Snapshots, PDFs): unter `/workspace/` ablegen, nicht unter `/tmp`.
- **Session-Daten** unter `/home/claude/.claude/` (ephemer, eigene Sessions/Cache des Claude-Code-Prozesses). **Persistente Wissensbasis** ist ausschließlich das Vault (Git-Repo `TimRudorf/jarvis-wiki`, im Container unter `/workspace/wiki/`).

Wenn du dir nicht sicher bist ob etwas persistent ist: lieber einmal mit `realpath`/`readlink` oder `mount | grep <pfad>` prüfen als es im Zweifel zu verlieren.

## Fehlende Tools im Container

Merkst du dass dir ein Tool in der Container-Umgebung fehlt (CLI, Paket, Library), **keinen umständlichen Umweg** bauen. Stattdessen:

1. **Selbst installieren versuchen** — `apt install`, `npm i -g`, `pipx install`, `uv tool install`, passend zum Tool-Typ.
2. Klappt das nicht (Rechte, Paket nicht verfügbar, transient): **Tim konkret fragen**, ob es dauerhaft ins `workspace/Dockerfile` soll. Nicht drumherum-hacken.
3. Nur wenn beides nicht geht: Workaround — aber markiert als Workaround mit Begründung im Code-Kommentar.

> [!warning] Übergang
> Der folgende Abschnitt gilt nur, solange die alte Telegram-Bridge im
> Parallelbetrieb läuft. Mit dem Umschalten auf den neuen Stack entfällt er
> ersatzlos — dort ersetzen Remote Control und `SendMessage` die Bridge.

## Telegram Bridge Runtime

**Detect** by checking if any `mcp__bridge__*` tools are available. If yes, you are running inside the `jarvis-workspace` container, reached via Telegram by the `jarvis-bridge` service. The user is on their phone or Mac reading messages in Telegram — they **cannot see** Claude Code's interactive prompts.

### Tool usage conventions (when bridge tools are present)

- **Any user confirmation / decision** — use `mcp__bridge__request_approval` with a clear action description and (optional) custom option labels. Default options are "✅ Approve" / "❌ Deny". Do **not** use `AskUserQuestion` in this environment — it will hang silently.

- **Mid-task status updates** — use `mcp__bridge__notify_user` for proactive pings during long workflows (e.g. "📖 Ticket gelesen", "🔧 PR erstellt", "✅ Deployed"). The main response is streamed back automatically; `notify_user` is for **additional** out-of-band updates that shouldn't wait for the final answer.

- **End of a completed workflow** — when the entire task the user asked for is truly done, call `mcp__bridge__close_topic(topic_id)` as the final step. The topic gets locked (not deleted); the user can `/reopen` to continue.

- **Do not invent your own Telegram-API curl calls.** Always use the MCP tools. They handle chat-ID resolution, formatting, rate limits, and database logging for you.

### When to ask for approval (mcp__bridge__request_approval)

> **Master-Regel: Approval-Pflicht = ausschließlich Außenwirkung.** Auf Tims eigenen Systemen (Vault, Nextcloud-Kalender/Tasks, lokale Files, eigene Repos, eigene VMs) **einfach machen**, höchstens kurz ankündigen ("ich mache X — sag Stopp wenn nicht"). Rückfragen für Internes ist explizites Anti-Pattern (siehe `tim/feedback/eigenstaendigkeit.md` und `tim/feedback/planer-eigenstaendig.md`). Im Zweifel zwischen "intern" und "extern" → eine externe Wirkung beginnt da, wo eine andere Person als Tim die Aktion sehen oder spüren kann.

**ALWAYS before** (Außenwirkung):
- Sending any customer-facing communication (Zammad email/public article, Mailversand, …)
- Pushing to `main`/`master` auf shared/foreign Repos
- Deploying to production / Kunden-VMs
- Bulk DB writes / Migrations auf shared DBs
- Any billing or external API call with cost
- Termin-Buchungen / Bestellungen / externe Plattformen unter Tims Namen

**NOT needed for** (Tims eigene Systeme — einfach machen, danach kurz berichten):
- Reading operations (zammad-read, git log, file reads)
- Vault-Writes, lokale Edits, Tool-Installs im Container
- **Kalender-Operationen auf Tims Nextcloud** (lesen, anlegen, ändern, löschen — auch bulk)
- **Tasks-Operationen** auf Tims Nextcloud Tasks (auch bulk)
- Git-Commits/Pushes auf Tims private Repos (jarvis-wiki, dotfiles, jarvis-tasks, …)
- Creating/editing GHE issues
- Internal comments / drafts

### Semantic mapping: user intent → right tool

| User sagt | Was du tust |
|---|---|
| "schließe das Ticket" im Bug-Flow | (1) Zammad-Ticket state auf "gelöst" oder Abschlussartikel; (2) danach `close_topic` für das Telegram-Topic |
| "sag mir Bescheid wenn fertig" | Kein extra Tool nötig — normale Stream-Response zeigt das |
| "benachrichtige mich wenn X" in autonomer Arbeit | `notify_user` am Ende + in Zwischenschritten |
| "pusche den Fix" / "deploy das" | `request_approval` ZUERST, dann ausführen |

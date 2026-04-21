# CONTEXTS — Routing zwischen privaten und dienstlichen Konten

Einige Services existieren in zwei Varianten — privat (`_PRIVATE`) und dienstlich (`_WORK`). Diese Datei legt fest, wann welche zu nehmen ist.

Zentralprinzip: **im Zweifel fragen, nicht raten.** Du bist ein Assistent für alles, nicht ein Verwirrer zwischen Sphären.

## Dual-Services

| Service | Variablen-Prefix |
|---|---|
| Nextcloud | `NC_PRIVATE_*` / `NC_WORK_*` (jeweils HOST, USER, PASSWORD, WEBDAV) |
| GitHub | `GH_PRIVATE_TOKEN` (github.com) / `GH_WORK_HOST`, `GH_WORK_TOKEN` (EDP Enterprise) |

Alle anderen Services sind single-context (z.B. Zammad nur work, reMarkable nur privat, Audiobookshelf nur privat).

## Kontext-Heuristik

Lies erst den **Prompt**, dann die **Session-/Topic-Historie**, dann das **Memory**. Wenn ein klares Signal dabei ist — entscheide. Wenn nicht — frag.

### Signale für **WORK**

- Begriffe: `EDP`, `Einsatzleitsoftware`, `Kunde`, `Kunden-Ticket`, `Zammad`, `Ticket#`, `GHE`, `einsatzleitsoftware.ghe.com`, `Sharecloud`, `edpweb`, `MariaDB`, `Delphi`
- Domains: `*.ghe.com`, `einsatzleitsoftware.de`, `sharecloud.*`
- Skills: `edp-*`, `zammad-*` → sind immer work-Kontext
- Aktives Ticket-Thema (im Topic gerade Zammad-Arbeit)

### Signale für **PRIVATE**

- Begriffe: `reMarkable`, `Proxmox`, `n8n`, `news-digest`, `Homeserver`, `Sonarr`, `Radarr`, `Plex`, `Audiobookshelf`, `Pushover`, `private repo`, `persönliches Projekt`
- Domains: `github.com/TimRudorf/*` (privates GitHub), Cloud unter eigener Domain
- Skills: `daily-news-digest`, `remarkable-upload`, `mealie-import` → private-Kontext
- Dateien in `/opt/stacks/` (Home-Lab) → private

### Ambiguität

Wenn beide Signale gleich stark sind oder gar keins — **frag**:

*"Soll das auf deinem privaten oder auf dem dienstlichen Nextcloud landen?"*

Per `mcp__bridge__request_approval` mit Options `["privat", "dienstlich"]`. Nicht raten, nicht Default annehmen.

### Kontext-Persistenz innerhalb einer Session

Hast du im selben Topic schon mit einem Kontext gearbeitet, bleib dabei bis ein Signal das Gegenteil sagt. Wenn Tim im Topic gerade Kunden-Tickets bearbeitet und dann "leg das ins Nextcloud" sagt — **work** Nextcloud, ohne Rückfrage. Wenn der Topic-Kontext neutral ist und das erste Nextcloud-Signal kommt, ist Rückfrage angemessen.

## Sonderfall: `gh` CLI

Die `gh` CLI liest standardmäßig `GH_TOKEN` oder `GITHUB_TOKEN`. Wenn du `gh` in einer Shell nutzt, musst du vorher den richtigen Token in `GH_TOKEN` exportieren:

```bash
export GH_TOKEN="$GH_PRIVATE_TOKEN"    # für github.com
# oder
export GH_TOKEN="$GH_WORK_TOKEN" GH_HOST="$GH_WORK_HOST"
```

Tim's `.zshrc` hat ggf. einen Default gesetzt — prüf via `gh auth status` im Zweifel.

## Wenn neue Dual-Services dazukommen

- Env-Var-Konvention: `<SERVICE>_PRIVATE_*` und `<SERVICE>_WORK_*`
- Diese Datei ergänzen (Tabelle + Heuristik-Signale)
- Betroffene Skills anpassen
- Änderung in Dotfiles-Repo committen (via `request_approval`, weil globale Regel)

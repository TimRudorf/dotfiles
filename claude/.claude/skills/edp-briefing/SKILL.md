---
name: edp-briefing
description: This skill should be used when the user asks for a "daily briefing", "open tasks overview", "what's pending", or uses /edp-briefing. It shows open Zammad tickets, GitHub Issues, and PRs.
---

# Tägliches Briefing

Zeigt einen Überblick über alle offenen Aufgaben: Zammad-Tickets, GitHub Issues und PRs.

## Configuration

- Zammad: Environment variables from `~/Develop/EDP/.env` (`ZAMMAD_HOST`, `ZAMMAD_TOKEN`)
- GitHub: MCP-Server `github` (konfiguriert für `einsatzleitsoftware.ghe.com`)

## Workflow

### Schritt 1: Daten parallel sammeln

Alle folgenden Abfragen **parallel** ausführen (separate Bash-Aufrufe):

**1a) Offene Zammad-Tickets** (Status `new` oder `open`, Owner = Tim):

```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"
AUTH="Authorization: Token token=${ZAMMAD_TOKEN}"

curl -s -H "$AUTH" "$BASE/api/v1/tickets/search?query=owner.email:tim.rudorf@einsatzleitsoftware.de+AND+(state.name:new+OR+state.name:open)&expand=true&limit=50" > /tmp/z_briefing_open.json \
  && jq '[.[] | {id, number, title, state, customer, organization, updated_at}]' /tmp/z_briefing_open.json
```

**1b) Zammad-Tickets "Warten auf Rückmeldung"** (`pending close` oder `warten auf Rückmeldung -extern`):

```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"
AUTH="Authorization: Token token=${ZAMMAD_TOKEN}"

curl -s -H "$AUTH" "$BASE/api/v1/tickets/search?query=owner.email:tim.rudorf@einsatzleitsoftware.de+AND+(state.name:%22pending+close%22+OR+state.name:%22warten+auf+Rückmeldung+-extern%22)&expand=true&limit=50" > /tmp/z_briefing_pending_close.json \
  && jq '[.[] | {id, number, title, customer, organization, updated_at}]' /tmp/z_briefing_pending_close.json
```

→ Danach filtern: nur Tickets mit `updated_at` **älter als 14 Tage** anzeigen.

**1c) Zammad-Tickets "Warten auf Erinnerung"** (`pending reminder`):

```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"
AUTH="Authorization: Token token=${ZAMMAD_TOKEN}"

curl -s -H "$AUTH" "$BASE/api/v1/tickets/search?query=owner.email:tim.rudorf@einsatzleitsoftware.de+AND+state.name:%22pending+reminder%22&expand=true&limit=50" > /tmp/z_briefing_pending_reminder.json \
  && jq '[.[] | {id, number, title, customer, organization, updated_at, pending_time}]' /tmp/z_briefing_pending_reminder.json
```

→ Danach filtern: nur Tickets mit `pending_time` **in der Vergangenheit** (Erinnerung abgelaufen).

**1d) GitHub Issues** (assigned to me):

```tool
mcp__github__search_issues(query: "assignee:tim-rudorf state:open", owner: "edp")
```

**1e) GitHub PRs** (die mich betreffen):

```tool
mcp__github__search_pull_requests(query: "state:open involves:tim-rudorf", owner: "edp")
```

Danach für jeden gefundenen PR den Review-Status separat abfragen (parallel):

```tool
mcp__github__pull_request_read(method: "get_reviews", owner: "edp", repo: <repo>, pullNumber: <nr>)
```

### Schritt 2: Zusammenfassungen generieren

Für jedes Ticket/Issue/PR eine **kurze Zusammenfassung** (1 Satz oder wenige Stichpunkte) erstellen:

**Zammad-Tickets**: Für jedes Ticket den letzten Kundenartikel laden:

```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"
AUTH="Authorization: Token token=${ZAMMAD_TOKEN}"

curl -s -H "$AUTH" "$BASE/api/v1/ticket_articles/by_ticket/{TICKET_ID}" > /tmp/z_articles_{TICKET_ID}.json \
  && jq -r '[.[] | select(.sender == "Customer")] | last | .body | gsub("<[^>]*>"; " ") | gsub("&gt;"; ">") | gsub("&lt;"; "<") | gsub("&amp;"; "&") | gsub("\\s+"; " ") | ltrimstr(" ")' /tmp/z_articles_{TICKET_ID}.json
```

Den Body-Text auf max. 1-2 Sätze **AI-zusammenfassen** (keine bloße Textabschneidung).

**GitHub Issues & PRs**: Das `body`-Feld aus den JSON-Ergebnissen von Schritt 1d/1e verwenden und AI-zusammenfassen.

**Parallelisierung**: Alle Artikel-Abrufe für Zammad-Tickets können parallel erfolgen. Die Zusammenfassungen selbst werden vom AI-Modell inline generiert.

### Schritt 3: Daten aufbereiten & filtern

Folgende Logik anwenden:

**Issues mit zugehörigem PR entfernen**: Wenn ein offener PR existiert, der eine Issue-Nummer im Title enthält (z.B. `#5`) oder dessen Branch auf ein Issue verweist, dieses Issue aus der "Offene Issues"-Liste entfernen (es ist bereits "in Bearbeitung" via PR).

**PRs kategorisieren**:
- **"Review ausstehend"** — ich bin Reviewer und habe noch kein Review abgegeben
- **"Wartet auf Review"** — mir assigned, mindestens ein angefordertes Review seit **>= 3 Tagen** ausstehend (anhand `created_at` des PRs oder des letzten Commits). Wenn < 3 Tage: PR nicht anzeigen.
- **"Merge bereit"** — mir assigned, alle Reviews approved
- **"Änderungen nötig"** — Changes requested an mich, oder CI failed

**Zammad "Warten auf Rückmeldung"**: Nur Tickets anzeigen, bei denen `updated_at` > 14 Tage zurückliegt.

**Zammad "Erinnerung abgelaufen"**: Nur Tickets anzeigen, bei denen `pending_time` in der Vergangenheit liegt.

**Verknüpfungen aufzeigen**: Wenn ein Zammad-Ticket eine Issue-Nummer (z.B. `#5` oder `edp/repo#5`) oder ein PR eine Ticket-Nummer (z.B. `EDP#762...`) referenziert, diese Verknüpfung in der Ausgabe anzeigen.

### Schritt 4: Ausgabe formatieren

Strukturierte Markdown-Ausgabe direkt an den User (kein `AskUserQuestion`):

```
# Briefing — {Datum}

## Zammad — Offene Tickets ({Anzahl})

| # | Titel | Status | Kunde | Zusammenfassung | Aktualisiert | Verknüpfung |
|---|-------|--------|-------|-----------------|--------------|-------------|
| 762... | ... | offen | ... | Kurzbeschreibung in 1 Satz | vor 2 Tagen | → Issue edp/repo#5 |

---

## Zammad — Warten auf Rückmeldung ({Anzahl})

| # | Titel | Kunde | Zusammenfassung | Wartet seit |
|---|-------|-------|-----------------|-------------|
| 761... | ... | ... | Kurzbeschreibung | 18 Tage |

---

## Zammad — Erinnerung abgelaufen ({Anzahl})

| # | Titel | Kunde | Zusammenfassung | Erinnerung seit |
|---|-------|-------|-----------------|-----------------|
| 760... | ... | ... | Kurzbeschreibung | vor 3 Tagen |

---

## GitHub — Offene Issues ({Anzahl})

Gruppiert nach Repository:

### edp/repo-name
| # | Titel | Labels | Zusammenfassung | Aktualisiert |
|---|-------|--------|-----------------|------------|
| 5 | ... | bug | Kurzbeschreibung | vor 3 Tagen |

---

## GitHub — PRs mit Handlungsbedarf ({Anzahl})

### Review ausstehend
| Repo | # | Titel | Autor | Zusammenfassung | Aktualisiert |
|------|---|-------|-------|-----------------|------------|

### Wartet auf Review
| Repo | # | Titel | Reviews ausstehend seit | Zusammenfassung | Aktualisiert |
|------|---|-------|-------------------------|-----------------|------------|

### Merge bereit
| Repo | # | Titel | Reviews | Zusammenfassung | Aktualisiert |
|------|---|-------|---------|-----------------|------------|

### Änderungen nötig
| Repo | # | Titel | Status | Zusammenfassung | Aktualisiert |
|------|---|-------|--------|-----------------|------------|
```

Kategorien ohne Einträge **komplett ausblenden** (keine Überschrift, keine Tabelle).

## Regeln

- **GitHub-Abfragen** über MCP-Tools (`mcp__github__*`) — kein `gh` CLI für GitHub-Daten
- **Immer** `source ~/Develop/EDP/.env` für Zammad-Credentials
- **Immer** curl-Output in temp files speichern, dann mit `jq` verarbeiten
- **Immer** `?expand=true` bei der Zammad Tickets API verwenden
- Alle Datenabfragen in Schritt 1 **maximal parallel** ausführen
- **Keine** `AskUserQuestion` — reines Informations-Briefing
- **Relative Zeitangaben** verwenden (z.B. "vor 3 Tagen", "18 Tage")
- **Deutsche Sprache** in der Ausgabe

---

## Skill-Optimierung

Nach Abschluss dieses Skills kurz bewerten, ob Optimierungsbedarf besteht:

- **Empfehlung "ja"**: Fehler aufgetreten, Workarounds nötig, Befehle wiederholt, User-Korrekturen
- **Empfehlung "nein"**: Reibungsloser Lauf wie dokumentiert

Per `AskUserQuestion` fragen:

> Skill abgeschlossen. Soll die Skill-Dokumentation optimiert werden?
> Empfehlung: {ja — [kurzer Grund] | nein — Lauf war reibungslos}

Optionen: **"Ja, optimieren"**, **"Nein"**

Bei "Ja": `skill-optimize` mit Skill-Name `edp-briefing` ausführen.

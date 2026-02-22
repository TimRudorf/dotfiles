---
name: edp-briefing
description: This skill should be used when the user asks for a "daily briefing", "open tasks overview", "what's pending", or uses /edp-briefing. It shows open Zammad tickets, GitHub Issues, and PRs.
---

# Tägliches Briefing

Zeigt einen Überblick über alle offenen Aufgaben: Zammad-Tickets, GitHub Issues und PRs.

## Voraussetzungen
- Env: `ZAMMAD_HOST`, `ZAMMAD_TOKEN`
- Tools: `gh`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Workflow

### Schritt 1: Daten parallel sammeln (Subagent-Delegation)

Zwei Subagents **parallel** starten, um die Rohdaten zu beschaffen, filtern und zusammenfassen. Jeder Subagent liefert **nur** die unten beschriebenen Felder zurück — keine Rohdaten, kein HTML, keine unnötigen Felder.

#### 1a) Zammad-Daten (Subagent: `zammad-expert`)

**Was wird gebraucht:**
Alle Zammad-Tickets von Owner `tim.rudorf@einsatzleitsoftware.de`, aufgeteilt in 3 Kategorien. Für jedes Ticket den letzten Kundenartikel lesen und auf 1 Satz AI-zusammenfassen.

**Rückgabeformat** — pro Ticket:
```json
{"nummer": 762, "titel": "...", "status": "open", "kunde": "...", "organisation": "...", "updated_at": "...", "zusammenfassung": "Ein-Satz-Zusammenfassung"}
```

**Kategorie 1 — Offene Tickets**: Status `new` oder `open`
→ Alle Treffer zurückgeben.

**Kategorie 2 — Warten auf Rückmeldung**: Status `pending close` oder `warten auf Rückmeldung -extern`
→ **Nur** Tickets mit `updated_at` älter als 14 Tage. Tickets mit jüngeren Updates: weglassen.

**Kategorie 3 — Erinnerung abgelaufen**: Status `pending reminder`
→ **Nur** Tickets mit `pending_time` in der Vergangenheit. Zusatzfeld `pending_time` im Ergebnis. Tickets mit zukünftiger pending_time: weglassen.

#### 1b) GitHub-Daten (Subagent: `git-expert`)

**Was wird gebraucht:**
Offene Issues und PRs aus der GitHub-Org `edp`, die `tim-rudorf` betreffen.

**Issues — Rückgabeformat** — pro Issue:
```json
{"nummer": 5, "titel": "...", "repo": "edpweb", "labels": ["bug"], "zusammenfassung": "Ein-Satz-Zusammenfassung", "updated_at": "..."}
```
→ Nur offene Issues assigned to `tim-rudorf` in Org `edp`.
→ Issues die einen zugehörigen **offenen PR** haben (PR-Titel enthält `#<nummer>` oder Branch verweist auf Issue): **weglassen**.

**PRs — Rückgabeformat** — pro PR:
```json
{"nummer": 42, "titel": "...", "repo": "edpweb", "autor": "...", "zusammenfassung": "Ein-Satz-Zusammenfassung", "updated_at": "...", "kategorie": "Review ausstehend"}
```
→ `kategorie` bereits bestimmt als einer von:
  - **"Review ausstehend"** — `tim-rudorf` ist Reviewer und hat noch kein Review abgegeben
  - **"Wartet auf Review (>3 Tage)"** — `tim-rudorf` ist Autor, mindestens ein angefordertes Review seit >= 3 Tagen ausstehend
  - **"Merge bereit"** — `tim-rudorf` ist Autor, alle Reviews approved
  - **"Änderungen nötig"** — Changes requested an `tim-rudorf`, oder CI failed

→ PRs ohne Handlungsbedarf (Wartet auf Review < 3 Tage, keine Kategorie zutreffend): **weglassen**.

### Schritt 2: Daten aufbereiten & filtern

Folgende Logik im Main-Agent anwenden:

**Verknüpfungen aufzeigen**: Wenn ein Zammad-Ticket eine Issue-Nummer (z.B. `#5` oder `edp/repo#5`) oder ein PR eine Ticket-Nummer (z.B. `EDP#762...`) referenziert, diese Verknüpfung in der Ausgabe anzeigen.

### Schritt 3: Ausgabe formatieren

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

- **GitHub-Abfragen** über `gh` CLI oder Subagent-Delegation — kein MCP
- Zammad-Credentials (`ZAMMAD_HOST`, `ZAMMAD_TOKEN`) sind via `.zshrc` automatisch verfügbar
- Alle Datenabfragen in Schritt 1 **maximal parallel** ausführen
- **Keine** `AskUserQuestion` — reines Informations-Briefing
- **Relative Zeitangaben** verwenden (z.B. "vor 3 Tagen", "18 Tage")
- **Deutsche Sprache** in der Ausgabe

Abschließend `skill-optimize` mit `edp-briefing` aufrufen.

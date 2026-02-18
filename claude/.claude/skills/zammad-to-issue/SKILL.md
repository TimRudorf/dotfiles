---
name: zammad-to-issue
description: This skill should be used when the user asks to "create a GitHub issue from a Zammad ticket", "convert ticket to issue", or uses /zammad-to-issue. It creates structured GHE issues from Zammad tickets.
argument-hint: [ticket-number]
---

# Zammad → GitHub Issue

Erstellt aus einem Zammad-Ticket ein strukturiertes GitHub Issue auf `einsatzleitsoftware.ghe.com`.

## Workflow

### Schritt 1: Zammad-Ticket auslesen

Lies das Zammad-Ticket gemäß `~/.claude/skills/zammad-read/SKILL.md` aus. Analysiere den Inhalt und bestimme die Kategorie:

- **Bug**: Fehlerbeschreibung, unerwartetes Verhalten, Absturz
- **Feature**: Neue Funktionalität, Erweiterung
- **Verbesserung**: Optimierung bestehender Funktionen

#### Internes vs. externes Ticket bestimmen

Prüfe das Feld `organization` des Tickets:

- **Intern**: Organisation ist `"Eifert Systems GmbH"` → Ticket stammt von einem eigenen Mitarbeiter
- **Extern**: Jede andere Organisation → Ticket stammt von einem Kunden

Merke dir den Wert von `customer` (Name des Erstellers) — dieser wird bei internen Tickets in der Referenz verwendet.

#### GitHub-Account des Erstellers prüfen (nur bei internen Tickets)

Bei internen Tickets prüfen, ob der Ersteller einen GitHub-Account auf der GHE-Instanz hat. Dazu die Mitgliederliste der Organisation abfragen:

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh api '/orgs/edp/members' --jq '.[].login'
```

Den Login anhand des Namens aus dem Zammad-Ticket zuordnen (z.B. "hendrik.eifert@..." → `hendrik-eifert`). Falls ein passender Account gefunden wird, diesen für die Referenz im Issue-Body verwenden (siehe Referenz-Varianten).

### Schritt 2a: Daten vom Server abrufen

**Parallel** alle Metadaten prefetchen (bevor der User gefragt wird):

**Repos** (MCP):
```tool
mcp__github__search_repositories(query: "org:edp", perPage: 50)
```

**Issue Types** (MCP):
```tool
mcp__github__list_issue_types(owner: "edp")
```

**Assignees** (Bash — kein MCP-Äquivalent):
```bash
GH_HOST=einsatzleitsoftware.ghe.com gh api '/orgs/edp/members' --jq '.[].login'
```

**Projects** (Bash — kein MCP-Äquivalent):
```bash
GH_HOST=einsatzleitsoftware.ghe.com gh api graphql -f query='
  query {
    organization(login: "edp") {
      projectsV2(first: 20) {
        nodes { id number title }
      }
    }
  }
' --jq '.data.organization.projectsV2.nodes[] | "\(.number): \(.title)"'
```

**Labels werden hier NICHT abgefragt** — sie hängen vom gewählten Repo ab (→ Schritt 2c).

### Schritt 2b: Repo auswählen

`AskUserQuestion` mit:
1. Vorgeschlagenes Repo `(Empfohlen)` — basierend auf Ticket-Inhalt
2. 2 weitere wahrscheinliche Repos
3. `Abbruch`

Repo ist Pflichtfeld → kein "Kein Wert setzen". Weitere Repos via "Other".

Bei "Abbruch": Skill bricht sofort ab mit Meldung "Skill abgebrochen."

### Schritt 2c: Labels abrufen und pro Kategorie auswählen

1. Labels für gewähltes Repo fetchen:

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh label list -R edp/<repo> --json name,description --limit 100
```

2. Labels am `:` aufteilen → `kategorie:wert`
3. **`merge:*` Labels ausschließen** (werden automatisch vom Server gesetzt)
4. Pro Kategorie eine `AskUserQuestion`:
   - Vorschlag `(Empfohlen)` falls einer sinnvoll, sonst ohne
   - Alle Werte der Kategorie als Optionen
   - `Kein Wert setzen`
   - Bei >4 Optionen: die wahrscheinlichsten 2-3 + "Kein Wert setzen", Rest via "Other"

Beispiel für `priority`-Kategorie (3 Labels):
1. `priority:prioritized (Empfohlen)`
2. `priority:release`
3. `priority:unprioritized`
4. `Kein Wert setzen`

Labels ohne `:` werden einzeln als eigene Frage behandelt (z.B. "Label `security` setzen?" → Ja/Nein).

Bei "Abbruch" (via "Other"): Skill bricht sofort ab mit Meldung "Skill abgebrochen."

### Schritt 2d: Type auswählen

Falls der User einen Type als Argument mitgegeben hat → diesen Schritt überspringen.

`AskUserQuestion` mit verfügbaren Types:
1. Vorschlag `(Empfohlen)` basierend auf Ticket-Analyse (Bug/Feature/Verbesserung)
2. Weitere Types
3. `Kein Wert setzen`

Bei "Abbruch" (via "Other"): Skill bricht sofort ab mit Meldung "Skill abgebrochen."

### Schritt 2e: Assignee auswählen

`AskUserQuestion`:
1. `tim-rudorf (Empfohlen)` — immer Default
2. 2 weitere Org-Mitglieder
3. `Kein Wert setzen`

Bei "Abbruch" (via "Other"): Skill bricht sofort ab mit Meldung "Skill abgebrochen."

### Schritt 2f: Project auswählen

`AskUserQuestion` mit verfügbaren Projects:
1. Vorschlag `(Empfohlen)` basierend auf Inhalt
2. Weitere Projects
3. `Kein Wert setzen`

Typische Zuordnung:
- Feature/Bug für aktuelle Entwicklung → aktuelles Release-Project (z.B. "Release 2026.1.0")
- Grundlegende Architekturthemen → "Go edp:server" o.ä.

Bei "Abbruch" (via "Other"): Skill bricht sofort ab mit Meldung "Skill abgebrochen."

### Schritt 3: Entwurf präsentieren

Vor dem Erstellen eine strukturierte Übersicht mit `AskUserQuestion` anzeigen:

```
Issue-Entwurf
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Repo:     edp/<repo>
Type:     <type>
Assignee: <assignee>
Labels:   <label1>, <label2>, ...
Project:  <project>
Herkunft: intern (<mitarbeiter>) / extern (<organisation>)

Titel: <titel>

Body:
──────
<vollständiger Body>
──────
```

Optionen: "Erstellen", "Ändern", "Abbrechen".

Bei "Ändern": User gibt an welches Feld → nur diese Frage erneut stellen (Schritt 2b-2f je nach Feld).

### Schritt 4: Issue erstellen

Nach Bestätigung das Issue erstellen:

#### 4a: Issue erstellen (MCP)

Issue per MCP-Tool erstellen. Der `type`-Parameter setzt den Issue-Type direkt — kein separater GraphQL-Schritt nötig. Felder mit "Kein Wert setzen" weglassen:

```tool
mcp__github__issue_write(
  method: "create",
  owner: "edp",
  repo: <repo>,
  title: <titel>,
  body: <body>,
  labels: [<label1>, <label2>],
  assignees: [<assignee>],
  type: <type>
)
```

#### 4b: Project zuordnen (Bash — kein MCP-Äquivalent)

Falls ein Project gewählt wurde:

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh issue edit <nr> -R edp/<repo> --add-project "<project>"
```

Nach dem Erstellen die Issue-URL dem User anzeigen.

### Schritt 5: Zammad-Ticket benachrichtigen und ggf. schließen

Da das Issue aus einem Zammad-Ticket erstellt wurde, ist die Zammad-Ticketnummer aus Schritt 1 bereits bekannt.

#### 5a: Internen Kommentar schreiben

Gemäß `~/.claude/skills/zammad-write/SKILL.md` einen internen Kommentar in das Zammad-Ticket schreiben:

- **Ticketnummer**: Die `<ticket_number>` aus Schritt 1
- **Body**: `Ein GitHub Issue wurde zu diesem Thema eröffnet: <issue-url> (Issue #<nummer> in edp/<repo>)`
- **Intern**: `true`

Die Bestätigung per `AskUserQuestion` aus dem /zammad-write Skill **überspringen** — der User hat das Issue bereits in Schritt 3 bestätigt. Stattdessen den Kommentar direkt absenden und das Ergebnis dem User anzeigen (Zammad-Ticketnummer + Hinweis dass kommentiert wurde).

#### 5b: Internes Ticket schließen

Wenn das Ticket **intern** ist (Organisation = "Eifert Systems GmbH"), das Zammad-Ticket nach dem Kommentar auf Status "closed" setzen:

```bash
source ~/.env
BASE="${ZAMMAD_HOST%/}"
AUTH="Authorization: Token token=${ZAMMAD_TOKEN}"

curl -s -X PUT \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  --data '{"state": "closed"}' \
  "$BASE/api/v1/tickets/<ticket_id>" > /tmp/z_close.json \
  && jq '{id, number, title, state}' /tmp/z_close.json
```

Bei **externen** Tickets das Ticket **nicht** schließen — es bleibt offen für weitere Kundenkommunikation.

**Fehlertoleranz**: Falls das Zammad-Ticket nicht gefunden wird oder die API fehlschlägt, den Fehler dem User anzeigen aber den Skill nicht abbrechen — das GitHub Issue wurde bereits erfolgreich erstellt.

## Issue-Struktur

### Titel

Prägnant, beschreibend, ohne Präfix-Tags. Maximal ~70 Zeichen.

### Body — Bug

```markdown
## Beschreibung

<Klare, zusammenfassende Beschreibung des Problems in 2-4 Sätzen.>

## Hintergrund

<Kontext: Wer ist betroffen, in welchem Bereich tritt das auf, warum ist es relevant.>

## Schritte zur Nachstellung

1. ...
2. ...
3. ...

## Erwartetes Verhalten

<Was sollte passieren.>

## Tatsächliches Verhalten

<Was passiert stattdessen.>

## Referenz

<siehe Referenz-Varianten unten>
```

### Body — Feature / Verbesserung

```markdown
## Beschreibung

<Klare, zusammenfassende Beschreibung der Anforderung in 2-4 Sätzen.>

## Hintergrund

<Kontext: Wer ist betroffen, in welchem Bereich tritt das auf, warum ist es relevant.>

## Anforderungen

- [ ] ...
- [ ] ...

## Referenz

<siehe Referenz-Varianten unten>
```

### Referenz-Varianten

Je nach Herkunft des Tickets unterschiedliche Formulierung:

- **Externes Ticket** (Kundenrückmeldung):
  ```
  Basierend auf Kundenrückmeldung via Zammad: `EDP#<ticket_number>`
  ```

- **Internes Ticket** (eigener Mitarbeiter):
  - Mit GitHub-Account:
    ```
    Internes Ticket von @<github_login>: `EDP#<ticket_number>`
    ```
  - Ohne GitHub-Account:
    ```
    Internes Ticket von <mitarbeiter_name>: `EDP#<ticket_number>`
    ```

## Regeln für den Inhalt

- **Deutsche Sprache**, professioneller Ton
- **Kein Hinweis** auf AI oder automatische Erstellung
- **Kein Copy-Paste** von Kunden-Mails — Inhalt wird in eigenen Worten zusammengefasst und fachlich aufbereitet
- Fachlich präzise, keine Füllwörter
- **Echte Umlaute** (ä, ö, ü, ß) verwenden — niemals ASCII-Umschreibungen (ae, oe, ue, ss)
- Bug vs. Feature/Verbesserung bestimmt welche Sektionen genutzt werden

## GHE-Spezifika

- **GitHub-Abfragen** bevorzugt über MCP-Tools (`mcp__github__*`)
- **Nur** `GH_HOST=einsatzleitsoftware.ghe.com` vor verbleibenden `gh`-Befehlen setzen (org members, projects, labels, project assign)
- User-Login: `tim-rudorf`
- Org: `edp`
- Alle Metadaten (Repos, Types, Projects, Labels) werden **live abgefragt**, nie hardcoded

---

## Skill-Optimierung

Nach Abschluss dieses Skills kurz bewerten, ob Optimierungsbedarf besteht:

- **Empfehlung "ja"**: Fehler aufgetreten, Workarounds nötig, Befehle wiederholt, User-Korrekturen
- **Empfehlung "nein"**: Reibungsloser Lauf wie dokumentiert

Per `AskUserQuestion` fragen:

> Skill abgeschlossen. Soll die Skill-Dokumentation optimiert werden?
> Empfehlung: {ja — [kurzer Grund] | nein — Lauf war reibungslos}

Optionen: **"Ja, optimieren"**, **"Nein"**

Bei "Ja": `skill-optimize` mit Skill-Name `zammad-to-issue` ausführen.

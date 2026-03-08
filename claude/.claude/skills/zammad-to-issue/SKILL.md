---
name: zammad-to-issue
description: This skill should be used when the user asks to "create a GitHub issue from a Zammad ticket", "convert ticket to issue", or uses /zammad-to-issue. It creates structured GHE issues from Zammad tickets.
argument-hint: [ticket-number]
---

# Zammad → GitHub Issue

Erstellt aus einem Zammad-Ticket ein strukturiertes GitHub Issue auf der GHE-Instanz.

## Voraussetzungen
- Env: `ZAMMAD_HOST`, `ZAMMAD_TOKEN`
- Tools: `curl`, `jq`, `gh`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

Alle User-Rückfragen gemäß `CLAUDE_COMM_CHANNEL` (siehe `.shared/communication.md`).

## Workflow

### Schritt 1: Zammad-Ticket auslesen (Subagent-Delegation)

Einen **Subagent** (`zammad-expert`) starten, der das Zammad-Ticket ausließt und fachlich aufbereitet.

**Was wird gebraucht:**
Ticket-Daten für Ticketnummer `$ARGUMENTS`, inklusive AI-aufbereiteter Zusammenfassung und Kategorisierung.

**Rückgabeformat:**
```json
{
  "ticket_id": 123,
  "ticket_number": "76200123",
  "titel": "...",
  "organisation": "Musterfirma GmbH",
  "customer": {"name": "Max Mustermann", "email": "max@example.com"},
  "kategorie": "Bug",
  "zusammenfassung": "Fachlich aufbereitete Zusammenfassung des Ticket-Inhalts in 2-4 Sätzen.",
  "schritte_nachstellung": ["Schritt 1", "Schritt 2"],
  "erwartetes_verhalten": "Was sollte passieren",
  "tatsaechliches_verhalten": "Was passiert stattdessen"
}
```

**Details:**
- `kategorie`: AI-bestimmt aus Inhalt — `Bug`, `Feature` oder `Verbesserung`
- `zusammenfassung`: Fachlich aufbereitete Zusammenfassung (2-4 Sätze), keine Copy-Paste von Kunden-Mails
- `schritte_nachstellung`: Falls Bug, extrahierte Schritte zur Nachstellung (oder `null`)
- `erwartetes_verhalten`, `tatsaechliches_verhalten`: Falls Bug (oder `null`)

**Nicht benötigt:** Rohe Artikel-Bodies, HTML, interne Notizen, Ticket-History.

#### Internes vs. externes Ticket bestimmen

Prüfe das Feld `organisation` des Ergebnisses:

- **Intern**: Organisation ist `"Eifert Systems GmbH"` → Ticket stammt von einem eigenen Mitarbeiter
- **Extern**: Jede andere Organisation → Ticket stammt von einem Kunden

### Schritt 2a: GitHub-Metadaten ermitteln (Subagent-Delegation)

Einen **Subagent** (`git-expert`) starten, der die GitHub-Metadaten beschafft.

**Was wird gebraucht:**
Repos, Issue-Types und Org-Mitglieder der GitHub-Org `edp`.

**Rückgabeformat:**
```json
{
  "repos": [{"name": "edpweb", "description": "EDP Web Client"}],
  "issue_types": [{"id": "...", "name": "Bug", "description": "..."}],
  "members": [{"login": "tim-rudorf"}, {"login": "patrick-vogel"}]
}
```

#### GitHub-Account des Erstellers prüfen (nur bei internen Tickets)

Bei internen Tickets den Login anhand des Namens aus dem Zammad-Ticket in der `members`-Liste zuordnen (z.B. "hendrik.eifert@..." → `hendrik-eifert`). Falls ein passender Account gefunden wird, diesen für die Referenz im Issue-Body verwenden (siehe Referenz-Varianten).

### Schritt 2b: Repo auswählen

User-Rückfrage (Kommunikationsweg gemäß `CLAUDE_COMM_CHANNEL`) mit:
1. Vorgeschlagenes Repo `(Empfohlen)` — basierend auf Ticket-Inhalt
2. 2 weitere wahrscheinliche Repos
3. `Abbruch`

Repo ist Pflichtfeld → kein "Kein Wert setzen". Weitere Repos via "Other".

Bei "Abbruch": Skill bricht sofort ab mit Meldung "Skill abgebrochen."

### Schritt 2c: Labels abrufen und pro Kategorie auswählen

Labels für gewähltes Repo fetchen:

```bash
gh label list -R edp/<repo> --json name,description --limit 100
```

→ `merge:*` Labels herausfiltern.

Labels am `:` aufteilen → `kategorie:wert`. Pro Kategorie eine User-Rückfrage (Kommunikationsweg gemäß `CLAUDE_COMM_CHANNEL`):
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

User-Rückfrage (Kommunikationsweg gemäß `CLAUDE_COMM_CHANNEL`) mit verfügbaren Types:
1. Vorschlag `(Empfohlen)` basierend auf Ticket-Analyse (Bug/Feature/Verbesserung)
2. Weitere Types
3. `Kein Wert setzen`

Bei "Abbruch" (via "Other"): Skill bricht sofort ab mit Meldung "Skill abgebrochen."

### Schritt 2e: Assignee auswählen

User-Rückfrage (Kommunikationsweg gemäß `CLAUDE_COMM_CHANNEL`):
1. `tim-rudorf (Empfohlen)` — immer Default
2. 2 weitere Org-Mitglieder
3. `Kein Wert setzen`

Bei "Abbruch" (via "Other"): Skill bricht sofort ab mit Meldung "Skill abgebrochen."

### Schritt 2f: Project auswählen

Projects abfragen:

```bash
gh api graphql -f query='
  query {
    organization(login: "edp") {
      projectsV2(first: 20) {
        nodes { id number title }
      }
    }
  }
' --jq '.data.organization.projectsV2.nodes[] | "\(.number): \(.title)"'
```

User-Rückfrage (Kommunikationsweg gemäß `CLAUDE_COMM_CHANNEL`) mit verfügbaren Projects:
1. Vorschlag `(Empfohlen)` basierend auf Inhalt
2. Weitere Projects
3. `Kein Wert setzen`

Typische Zuordnung:
- Feature/Bug für aktuelle Entwicklung → aktuelles Release-Project (z.B. "Release 2026.1.0")
- Grundlegende Architekturthemen → "Go edp:server" o.ä.

Bei "Abbruch" (via "Other"): Skill bricht sofort ab mit Meldung "Skill abgebrochen."

### Schritt 3: Entwurf präsentieren

Vor dem Erstellen eine Übersicht mit User-Rückfrage (Kommunikationsweg gemäß `CLAUDE_COMM_CHANNEL`) anzeigen. Folgende Infos: Repo, Type, Assignee, Labels, Project, Herkunft (intern/extern), Titel und vollständiger Body. Darstellungsformat frei wählen.

Optionen: "Erstellen", "Ändern", "Abbrechen".

Bei "Ändern": User gibt an welches Feld → nur diese Frage erneut stellen (Schritt 2b-2f je nach Feld).

### Schritt 4: Issue erstellen

Nach Bestätigung das Issue erstellen:

#### 4a: Issue erstellen

Felder mit "Kein Wert setzen" weglassen:

```bash
gh issue create -R edp/<repo> --title "<titel>" --body "<body>" --label "l1,l2" --assignee <assignee> --type <type>
```

#### 4b: Project zuordnen

Falls ein Project gewählt wurde:

```bash
gh issue edit <nr> -R edp/<repo> --add-project "<project>"
```

Nach dem Erstellen die Issue-URL dem User anzeigen.

### Schritt 5: Zammad-Ticket benachrichtigen und ggf. schließen

Da das Issue aus einem Zammad-Ticket erstellt wurde, ist die Zammad-Ticketnummer aus Schritt 1 bereits bekannt.

#### 5a: Internen Kommentar schreiben

Gemäß `~/.claude/skills/zammad-write/SKILL.md` einen internen Kommentar in das Zammad-Ticket schreiben:

- **Ticketnummer**: Die `<ticket_number>` aus Schritt 1
- **Body**: `Ein GitHub Issue wurde zu diesem Thema eröffnet: <issue-url> (Issue #<nummer> in edp/<repo>)`
- **Intern**: `true`

Die Bestätigung aus dem /zammad-write Skill **überspringen** — der User hat das Issue bereits in Schritt 3 bestätigt. Stattdessen den Kommentar direkt absenden und das Ergebnis dem User anzeigen (Zammad-Ticketnummer + Hinweis dass kommentiert wurde).

#### 5b: Internes Ticket schließen

Wenn das Ticket **intern** ist (Organisation = "Eifert Systems GmbH"), das Zammad-Ticket nach dem Kommentar auf Status "closed" setzen:

```bash
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

- **GitHub-Leseabfragen** über Subagent-Delegation — kein MCP
- **GitHub-Schreibaktionen** über `gh` CLI
- User-Login: `tim-rudorf`
- Org: `edp`
- Alle Metadaten (Repos, Types, Projects, Labels) werden **live abgefragt**, nie hardcoded

Abschließend `skill-optimize` mit `zammad-to-issue` aufrufen.

# Zammad → GitHub Issue

Erstellt aus einem Zammad-Ticket ein strukturiertes GitHub Issue auf `einsatzleitsoftware.ghe.com`.

## Workflow

### Schritt 1: Zammad-Ticket auslesen

Lies das Zammad-Ticket gemäß `~/.claude/skills/zammad-read/SKILL.md` aus. Analysiere den Inhalt und bestimme die Kategorie:

- **Bug**: Fehlerbeschreibung, unerwartetes Verhalten, Absturz
- **Feature**: Neue Funktionalität, Erweiterung
- **Verbesserung**: Optimierung bestehender Funktionen

### Schritt 2: Interaktive Abstimmung mit dem User

Vor dem Erstellen einen Entwurf zeigen. Folgende Metadaten abfragen und vorschlagen:

#### Repo

Aktuelle Repo-Liste abfragen:

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh repo list edp --limit 50
```

Basierend auf dem Ticket-Inhalt ein Repo vorschlagen. Bei Unsicherheit nachfragen.

#### Type

Verfügbare Issue-Types vom Server abfragen:

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh api orgs/edp/issue-types --jq '.[].name'
```

Basierend auf der Ticket-Analyse (Bug/Feature/Verbesserung) einen passenden Type vorschlagen. Bei Unsicherheit nachfragen.

#### Assignee

Immer `tim-rudorf`.

#### Project

User fragen (oder weglassen). Verfügbare Projects abfragen:

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh project list --owner edp
```

Falls der Token-Scope es nicht erlaubt, ohne Project fortfahren.

#### Milestone

Nicht setzen.

### Schritt 3: Entwurf präsentieren

Vor dem Erstellen eine strukturierte Übersicht mit `AskUserQuestion` anzeigen:

```
📋 Issue-Entwurf
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Repo:     edp/<repo>
Type:     <type>
Assignee: tim-rudorf
Project:  <project oder "–">

Titel: <titel>

Body:
──────
<vollständiger Body>
──────
```

Optionen: "Erstellen", "Ändern", "Abbrechen".

### Schritt 4: Issue erstellen

Nach Bestätigung das Issue in zwei Schritten erstellen:

#### 4a: Issue erstellen

Den Body immer per HEREDOC übergeben, um Formatierungsprobleme zu vermeiden:

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh issue create -R edp/<repo> \
  --title "<titel>" \
  --assignee tim-rudorf \
  --body "$(cat <<'EOF'
<body>
EOF
)"
```

#### 4b: Issue-Type per GraphQL setzen

Aus der Issue-URL die Nummer extrahieren, dann die Node-ID des Issues abfragen:

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh api graphql -f query='
  query { repository(owner: "edp", name: "<repo>") { issue(number: <nr>) { id } } }
' --jq '.data.repository.issue.id'
```

Anschließend den Type per Name setzen (kein separater Query für die Type-Node-ID nötig — `issueTypeName` wird direkt unterstützt):

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh api graphql -f query='
  mutation {
    updateIssueIssueType(input: {issueId: "<issue-node-id>", issueTypeName: "<type>"}) {
      issue { issueType { name } }
    }
  }
'
```

Nach dem Erstellen die Issue-URL dem User anzeigen.

### Schritt 5: Zammad-Ticket benachrichtigen

Da das Issue aus einem Zammad-Ticket erstellt wurde, ist die Zammad-Ticketnummer aus Schritt 1 bereits bekannt.

Gemäß `~/.claude/skills/zammad-write/SKILL.md` einen internen Kommentar in das Zammad-Ticket schreiben:

- **Ticketnummer**: Die `<ticket_number>` aus Schritt 1
- **Body**: `Ein GitHub Issue wurde zu diesem Thema eröffnet: <issue-url> (Issue #<nummer> in edp/<repo>)`
- **Intern**: `true`

Die Bestätigung per `AskUserQuestion` aus dem /zammad-write Skill **überspringen** — der User hat das Issue bereits in Schritt 3 bestätigt. Stattdessen den Kommentar direkt absenden und das Ergebnis dem User anzeigen (Zammad-Ticketnummer + Hinweis dass kommentiert wurde).

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

Basierend auf Kundenrückmeldung via Zammad: `EDP#<ticket_number>`
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

Basierend auf Kundenrückmeldung via Zammad: `EDP#<ticket_number>`
```

## Regeln für den Inhalt

- **Deutsche Sprache**, professioneller Ton
- **Kein Hinweis** auf AI oder automatische Erstellung
- **Kein Copy-Paste** von Kunden-Mails — Inhalt wird in eigenen Worten zusammengefasst und fachlich aufbereitet
- Fachlich präzise, keine Füllwörter
- **Echte Umlaute** (ä, ö, ü, ß) verwenden — niemals ASCII-Umschreibungen (ae, oe, ue, ss)
- Bug vs. Feature/Verbesserung bestimmt welche Sektionen genutzt werden

## GHE-Spezifika

- **Immer** `GH_HOST=einsatzleitsoftware.ghe.com` vor allen `gh`-Befehlen setzen
- User-Login: `tim-rudorf`
- Org: `edp`
- Alle Metadaten (Repos, Types, Projects) werden **live abgefragt**, nie hardcoded

---
name: edp-pull-request
description: This skill should be used when the user asks to "create a PR", "edit a PR", "open a pull request", or uses /pull-request. It creates or updates PRs on GHE with auto-generated title, body, and Zammad integration.
argument-hint: [pr-number]
---

# Pull Request erstellen oder bearbeiten

Erstellt oder bearbeitet einen Pull Request auf der GHE-Instanz.

## Voraussetzungen
- Tools: `gh`, `git`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Modus-Erkennung

- **Kein Argument** → **Create-Modus**: Neuen PR vom aktuellen Branch nach `dev` erstellen
- **Argument ist eine PR-Nummer** (z.B. `61`) → **Edit-Modus**: Bestehenden PR laden und bearbeiten

## Workflow

### Schritt 1+2: Kontext und Metadaten ermitteln (Subagent-Delegation)

Einen **Subagent** (`git-expert`) starten, der alle benötigten Informationen beschafft.

**Was wird gebraucht:**

**Rückgabeformat:**
```json
{
  "branch": "feature/42-neue-funktion",
  "repo": "edpweb",
  "ticket_nummer": 42,
  "commits_summary": ["abc1234 feat: erste Änderung", "def5678 fix: Korrektur"],
  "diff_stats": "3 files changed, 42 insertions(+), 10 deletions(-)\n src/foo.pas | 30 +++--\n src/bar.pas | 22 +++-",
  "user_login": "tim-rudorf",
  "projects": [{"nummer": 1, "titel": "Release 2026.1.0"}]
}
```

**Im Edit-Modus** zusätzlich:
```json
{
  "pr": {"titel": "...", "body": "...", "assignees": ["tim-rudorf"], "reviewer": ["patrick-vogel"]}
}
```

**Details zur Ermittlung:**
- `branch`: Aktueller Branch-Name
- `repo`: Aus Remote-URL extrahiert (z.B. `edp/edpweb` → `edpweb`)
- `ticket_nummer`: Aus Branch-Pattern `(bugfix|feature|hotfix|refactor)/<nummer>-*` extrahiert, oder `null`
- `commits_summary`: `git log dev..HEAD --oneline`
- `diff_stats`: `git diff dev...HEAD --stat`
- `user_login`: GitHub-Login (`gh api user --jq .login`)
- `projects`: `gh project list --owner edp` — Liste mit Nummer + Titel
- [Edit-Modus] `pr`: Bestehender PR via `gh pr view <nummer> -R edp/<repo> --json title,body,assignees,reviewRequests`

**Nicht benötigt:** Commit-Hashes (außer im Oneline-Format), vollständige Diffs, Branch-Topologie.

### Schritt 3: Project-Auswahl

Falls Projects verfügbar, per `AskUserQuestion` anbieten. Optionen: die gefundenen Projects + "Kein Project". Falls Project-Abfrage fehlgeschlagen, diesen Schritt überspringen.

### Schritt 4: PR-Entwurf generieren

#### Titel

Aus den Commits und dem Branch-Namen einen prägnanten Titel ableiten. Format: `<category>(<scope>): <beschreibung>`

- `category`: Aus dem Branch-Präfix ableiten (`bugfix/` → `fix`, `feature/` → `feat`, `refactor/` → `refactor`, `hotfix/` → `fix`)
- `scope`: Aus dem betroffenen Bereich (z.B. `elw`, `auth`, `api`)
- Maximal ~70 Zeichen

**Im Edit-Modus**: Den bestehenden Titel und Body als Basis nehmen und anhand der aktuellen Commits/Diffs verbessern.

#### Body

```markdown
## Zusammenfassung
<Bullet Points: Was wurde geändert und warum — aus den Commits und dem Diff ableiten>

## Änderungen
<Auflistung der geänderten Dateien/Bereiche>

## Testplan
- [ ] <Konkrete Testschritte basierend auf den Änderungen>

Closes #<nummer>
```

Die `Closes #<nummer>`-Zeile **nur** einfügen, wenn eine Ticket-Nummer aus dem Branch-Namen extrahiert wurde.

### Schritt 5: Entwurf präsentieren

Übersicht per `AskUserQuestion` zeigen. Folgende Infos: Repo, Branch + Ziel-Branch, Assignee, Reviewer, Project, Titel und vollständiger Body. Darstellungsformat frei wählen.

Optionen:
- **Create-Modus**: "Erstellen", "Ändern", "Abbrechen"
- **Edit-Modus**: "Aktualisieren", "Ändern", "Abbrechen"

Verhalten:
- **Erstellen/Aktualisieren** → weiter zu Schritt 6
- **Ändern** → User nach gewünschten Änderungen fragen, Entwurf anpassen, erneut präsentieren
- **Abbrechen** → Skill beenden

### Schritt 6: PR erstellen oder aktualisieren

#### Create-Modus

**6a: Branch pushen (falls nötig)**

```bash
git ls-remote --heads origin <branch>
```

Falls nicht vorhanden:

```bash
git push -u origin <branch>
```

**6b: PR erstellen**

```bash
gh pr create -R edp/<repo> --title "<titel>" --body "<body>" --head <branch> --base dev
```

**6c: Assignee, Reviewer & Copilot**

```bash
gh pr edit <pr-nummer> -R edp/<repo> --add-assignee tim-rudorf --add-reviewer patrick-vogel --add-reviewer copilot-pull-request-reviewer
```

**6d: Project zuordnen (optional)**

Falls ein Project gewählt wurde:

```bash
gh pr edit <pr-nummer> --add-project "<project>"
```

#### Edit-Modus

**6a: PR aktualisieren**

```bash
gh pr edit <nummer> -R edp/<repo> --title "<titel>" --body "<body>"
```

**6b: Assignee & Reviewer**

```bash
gh pr edit <nummer> -R edp/<repo> --add-assignee tim-rudorf --add-reviewer patrick-vogel --add-reviewer copilot-pull-request-reviewer
```

**6c: Project zuordnen (optional)**

Falls ein Project gewählt wurde:

```bash
gh pr edit <nummer> --add-project "<project>"
```

Nach dem Erstellen/Aktualisieren die PR-URL dem User anzeigen.

### Schritt 7: Zammad-Ticket benachrichtigen (nur Create-Modus)

Falls eine Ticket-Nummer aus dem Branch extrahiert wurde (Schritt 1):

**7a: Issue-Body auf Zammad-Referenz prüfen**

```bash
gh issue view <nummer> -R edp/<repo> --json body --jq .body
```

Im Body nach dem Pattern `EDP#<zammad-nummer>` suchen. Falls gefunden → weiter mit 7b. Falls nicht → Schritt überspringen.

**7b: Internen Kommentar per /zammad-write Skill schreiben**

Gemäß `~/.claude/skills/zammad-write/SKILL.md` einen internen Kommentar in das Zammad-Ticket schreiben:

- **Ticketnummer**: Die `<zammad-nummer>` aus dem Issue-Body
- **Body**: `Bugfix wurde umgesetzt und steht in einem Pull Request bereit: <pr-url> (GitHub Issue #<nummer>)`
- **Intern**: `true`

Die Bestätigung per `AskUserQuestion` aus dem /zammad-write Skill **überspringen** — der User hat den PR bereits in Schritt 5 bestätigt. Stattdessen den Kommentar direkt absenden und das Ergebnis dem User anzeigen (Zammad-Ticketnummer + Hinweis dass kommentiert wurde).

**Fehlertoleranz**: Falls das Zammad-Ticket nicht gefunden wird oder die API fehlschlägt, den Fehler dem User anzeigen aber den Skill nicht abbrechen — der PR wurde bereits erfolgreich erstellt.

## Regeln

- **GitHub-Leseabfragen** über Subagent-Delegation — kein MCP
- **GitHub-Schreibaktionen** über `gh` CLI
- **Deutsche Sprache** im PR-Body mit echten Umlauten (ä, ö, ü, ß)
- **Kein** `Co-Authored-By` Trailer
- **Kein Hinweis** auf AI oder automatische Erstellung im PR-Body
- Alle Metadaten (Repos, Projects) werden **live abgefragt**, nie hardcoded
- **Keine Labels** zuweisen
- Base-Branch ist immer `dev`
- Assignee ist immer `tim-rudorf`
- Reviewer sind immer `patrick-vogel` und `copilot-pull-request-reviewer`
- **Fehlertoleranz**: Fehlende GitHub-Scopes oder API-Fehler bei optionalen Schritten (Projects) überspringen statt abbrechen
- Bei Unsicherheiten den User fragen

Abschließend `skill-optimize` mit `edp-pull-request` aufrufen.

---
name: edp-pull-request
description: This skill should be used when the user asks to "create a PR", "edit a PR", "open a pull request", or uses /pull-request. It creates or updates PRs on GHE with auto-generated title, body, and Zammad integration.
argument-hint: "[pr-number]"
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

In einen **Subagent** auslagern: alle benötigten Informationen per `git`/`gh` beschaffen.

**Reines Abrufen, kein Urteil** — ein schnelles, günstiges Modell genügt.

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
- [Edit-Modus] `pr`: Bestehender PR via `gh pr view <nummer> -R einsatzleitsoftware.ghe.com/edp/<repo> --json title,body,assignees,reviewRequests`

**Nicht benötigt:** Commit-Hashes (außer im Oneline-Format), vollständige Diffs, Branch-Topologie.

### Schritt 3: Project-Auswahl

Falls Projects verfügbar, dem User anbieten. Optionen: die gefundenen Projects + "Kein Project". Falls Project-Abfrage fehlgeschlagen, diesen Schritt überspringen.

### Schritt 4: PR-Entwurf generieren

#### Titel

Aus den Commits und dem Branch-Namen einen prägnanten Titel ableiten. Format: `<category>(<scope>): <beschreibung>`

- `category`: Aus dem Branch-Präfix ableiten (`bugfix/` → `fix`, `feature/` → `feat`, `refactor/` → `refactor`, `hotfix/` → `fix`)
- `scope`: Aus dem betroffenen Bereich (z.B. `elw`, `auth`, `api`)
- Maximal ~70 Zeichen

**Im Edit-Modus**: Den bestehenden Titel und Body als Basis nehmen und anhand der aktuellen Commits/Diffs verbessern.

#### Body

Der Body wird von einem **Menschen** gelesen, der entscheiden muss. Er will
wissen, was sich ändert, warum, wo er hinschauen soll und was er prüfen muss —
sonst nichts.

🔴 **Regelgrundlage ist `~/.claude/rules/shared/texte.md`.** Sie gilt für jeden
Text, den dieser Skill erzeugt — PR-Titel, Body, Zammad-Kommentar — und wird
hier **nicht** wiederholt. Vor dem Absenden gegen ihre Abschnitte prüfen, allen
voran *Das Wesentliche zuerst*, *Was in einen Vorgang gehört*, *Bearbeiten,
nicht anhängen* und *Echte Umlaute*.

```markdown
<2–4 Zeilen ohne Überschrift: was sich ändert und warum. Closes #<nummer>.>

## Worauf ich beim Review schauen würde

| Wo | Warum |
|---|---|
| <Datei/Bereich> | <was daran heikel ist, oder welche Entscheidung darin steckt, der man widersprechen können soll> |

## Was geprüft ist

<Was grün ist, mit Zahlen — Tests, Live-Verifikation, und der Prüfstand des
lokalen Reviews („gegen `<sha>` geprüft, Schwerpunkte: …") samt der Punkte, die
ohne Befund blieben. Danach als Checkliste, was noch offen ist:>

- [ ] <konkreter Prüfschritt für den Reviewer>
```

Die `Closes #<nummer>`-Zeile **nur** einfügen, wenn eine Ticket-Nummer aus dem Branch-Namen extrahiert wurde.

Was **nicht** in den Body gehört und wo die Längengrenze liegt, steht in
`texte.md` → *Was in einen Vorgang gehört*. Der Prüfgriff für diesen Skill:
reißt der Entwurf die Faustzahl von einem Bildschirm, wurde Werdegang
mitgeschrieben — das ist kein Zeichen dafür, dass der PR groß ist.

### Schritt 5: Entwurf präsentieren

Übersicht dem User zeigen. Folgende Infos: Repo, Branch + Ziel-Branch, Assignee, Reviewer, Project, Titel und vollständiger Body. Darstellungsformat frei wählen.

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
gh pr create -R einsatzleitsoftware.ghe.com/edp/<repo> --title "<titel>" --body "<body>" --head <branch> --base dev
```

**6c: Assignee & Review**

Assignee setzen:

```bash
gh pr edit <pr-nummer> -R einsatzleitsoftware.ghe.com/edp/<repo> --add-assignee tim-rudorf
```

> **Kein Copilot-Review mehr.** Seit 2026-08-06 wird Copilot **nicht** angefordert — der Bot ist auf der GHE-Instanz inaktiv (in den letzten 40 edpweb-PRs kein einziges Review), `gh pr edit --add-reviewer copilot-pull-request-reviewer` ist ein stiller No-op, und die GraphQL-Anforderung braucht eine Bot-Node-ID, die sich ohne vorhandenes Review nicht ermitteln lässt. Stattdessen prüft ein skeptischer lokaler Agent per **`/edp-review`** — im Issue-Workflow **vor** dem Erstellen des PR (`issue-workflow-core.md` → Schritt 8). So beschreibt der Body den Endstand, und die Fix-Runde kostet keinen zweiten CI-Durchgang.

`patrick-vogel` wird **nicht** automatisch als Reviewer gesetzt — nur wenn der User es ausdrücklich sagt (dann `--add-reviewer patrick-vogel`).

**6d: Project zuordnen (optional)**

Falls ein Project gewählt wurde:

```bash
gh pr edit <pr-nummer> --add-project "<project>"
```

#### Edit-Modus

**6a: PR aktualisieren**

```bash
gh pr edit <nummer> -R einsatzleitsoftware.ghe.com/edp/<repo> --title "<titel>" --body "<body>"
```

**6b: Assignee & Reviewer**

```bash
gh pr edit <nummer> -R einsatzleitsoftware.ghe.com/edp/<repo> --add-assignee tim-rudorf
```

Kein Reviewer wird automatisch gesetzt (siehe Create-Modus: Copilot ist auf der GHE-Instanz inaktiv). Geprüft wird per `/edp-review`; dessen Ergebnis wird in den **Body eingearbeitet**, nicht als Kommentar angehängt. `patrick-vogel` nur auf ausdrückliche Ansage.

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
gh issue view <nummer> -R einsatzleitsoftware.ghe.com/edp/<repo> --json body --jq .body
```

Im Body nach dem Pattern `EDP#<zammad-nummer>` suchen. Falls gefunden → weiter mit 7b. Falls nicht → Schritt überspringen.

**7b: Internen Kommentar per /zammad-write Skill schreiben**

Gemäß `~/.claude/skills/zammad-write/SKILL.md` einen internen Kommentar in das Zammad-Ticket schreiben:

- **Ticketnummer**: Die `<zammad-nummer>` aus dem Issue-Body
- **Body**: `Bugfix wurde umgesetzt und steht in einem Pull Request bereit: <pr-url> (GitHub Issue #<nummer>)`
- **Intern**: `true`

Die Bestätigung aus dem /zammad-write Skill **überspringen** — der User hat den PR bereits in Schritt 5 bestätigt. Stattdessen den Kommentar direkt absenden und das Ergebnis dem User anzeigen (Zammad-Ticketnummer + Hinweis dass kommentiert wurde).

**Fehlertoleranz**: Falls das Zammad-Ticket nicht gefunden wird oder die API fehlschlägt, den Fehler dem User anzeigen aber den Skill nicht abbrechen — der PR wurde bereits erfolgreich erstellt.

## Regeln

- **GitHub-Leseabfragen** über Subagent-Delegation — kein MCP
- **GitHub-Schreibaktionen** über `gh` CLI
- **Jeder erzeugte Text** folgt `~/.claude/rules/shared/texte.md` — deutsch, echte
  Umlaute, Wesentliches zuerst, Korrekturen im Body statt als Nachtrag
- **Kein** `Co-Authored-By` Trailer
- **Kein Hinweis** auf AI oder automatische Erstellung im PR-Body
- Alle Metadaten (Repos, Projects) werden **live abgefragt**, nie hardcoded
- **Keine Labels** zuweisen
- Base-Branch ist immer `dev`
- Assignee ist immer `tim-rudorf`
- **Kein Reviewer** wird automatisch gesetzt — Copilot ist auf der GHE-Instanz inaktiv (Begründung im Create-Modus). Geprüft wird per `/edp-review`, im Issue-Workflow vor dem Erstellen. `patrick-vogel` NICHT automatisch — nur wenn der User es ausdrücklich verlangt.
- Alle `gh`-Aufrufe mit vollem GHE-Host: `-R einsatzleitsoftware.ghe.com/edp/<repo>` bzw. `--hostname einsatzleitsoftware.ghe.com` (sonst löst `gh` gegen github.com auf → "Could not resolve to a Repository")
- **Fehlertoleranz**: Fehlende GitHub-Scopes oder API-Fehler bei optionalen Schritten (Projects) überspringen statt abbrechen
- Bei Unsicherheiten den User fragen

Abschließend `skill-optimize` mit `edp-pull-request` aufrufen.

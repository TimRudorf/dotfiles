# Pull Request erstellen oder bearbeiten

Erstellt oder bearbeitet einen Pull Request auf `einsatzleitsoftware.ghe.com`.

## Modus-Erkennung

- **Kein Argument** → **Create-Modus**: Neuen PR vom aktuellen Branch nach `dev` erstellen
- **Argument ist eine PR-Nummer** (z.B. `61`) → **Edit-Modus**: Bestehenden PR laden und bearbeiten

## Workflow

### Schritt 1: Kontext ermitteln (parallel)

Folgende Informationen parallel abfragen:

```bash
GH_HOST=einsatzleitsoftware.ghe.com git branch --show-current
```

```bash
GH_HOST=einsatzleitsoftware.ghe.com git remote get-url origin
```

Repo-Name aus der Remote-URL extrahieren (z.B. `edp/edpweb`).

```bash
GH_HOST=einsatzleitsoftware.ghe.com git log dev..HEAD --oneline
```

```bash
GH_HOST=einsatzleitsoftware.ghe.com git diff dev...HEAD --stat
```

**Ticket-Nummer extrahieren**: Aus dem Branch-Namen das Pattern `(bugfix|feature|hotfix|refactor)/<nummer>-*` erkennen → `#<nummer>`. Falls kein Match, gibt es kein Ticket.

**Nur im Edit-Modus** — zusätzlich den bestehenden PR laden:

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh pr view <nummer> --json title,body,assignees,reviewRequests
```

### Schritt 2: Metadaten live abfragen (parallel)

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh api user --jq '.login'
```

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh project list --owner edp
```

**Fehlerbehandlung**: Falls `gh project list` wegen fehlender Scopes fehlschlägt (`read:project`), den Project-Schritt überspringen und den User kurz darauf hinweisen.

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

Strukturierte Übersicht per `AskUserQuestion` zeigen:

```
PR-Entwurf (<Create|Edit> #<nummer>)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Repo:      edp/<repo>
Branch:    <branch> → dev
Assignee:  tim-rudorf
Reviewer:  patrick-vogel, copilot-pull-request-reviewer
Project:   <project oder "–">

Titel: <titel>

Body:
──────
<vollständiger Body>
──────
```

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
GH_HOST=einsatzleitsoftware.ghe.com git ls-remote --heads origin <branch>
```

Falls nicht vorhanden:

```bash
GH_HOST=einsatzleitsoftware.ghe.com git push -u origin <branch>
```

**6b: PR erstellen**

Den Body immer per HEREDOC übergeben:

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh pr create \
  --base dev \
  --title "<titel>" \
  --assignee tim-rudorf \
  --reviewer patrick-vogel,copilot-pull-request-reviewer \
  --body "$(cat <<'EOF'
<body>
EOF
)"
```

**6c: Project zuordnen (optional)**

Falls ein Project gewählt wurde:

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh pr edit <pr-nummer> --add-project "<project>"
```

#### Edit-Modus

**6a: PR aktualisieren**

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh pr edit <nummer> \
  --title "<titel>" \
  --add-assignee tim-rudorf \
  --add-reviewer patrick-vogel,copilot-pull-request-reviewer \
  --body "$(cat <<'EOF'
<body>
EOF
)"
```

**6b: Project zuordnen (optional)**

Falls ein Project gewählt wurde:

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh pr edit <nummer> --add-project "<project>"
```

Nach dem Erstellen/Aktualisieren die PR-URL dem User anzeigen.

### Schritt 7: Zammad-Ticket benachrichtigen (nur Create-Modus)

Falls eine Ticket-Nummer aus dem Branch extrahiert wurde (Schritt 1):

**7a: Issue-Body auf Zammad-Referenz prüfen**

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh issue view <nummer> --json body --jq '.body'
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

- **Immer** `GH_HOST=einsatzleitsoftware.ghe.com` vor allen `gh`- und relevanten `git`-Befehlen setzen
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

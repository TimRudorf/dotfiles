---
name: gh-issue
description: >-
  Autonomer End-to-End-Orchestrator für ein GitHub-Issue in Tims eigenen Repos unter github.com/TimRudorf
  (Eintracht, n8n, wachalarm, tetra-decode, docker-compose, dotfiles, …). Nutzen, wenn Tim eine Issue-URL,
  ein `Repo#Nummer` oder eine Nummer aus einem seiner privaten Repos übergibt und sie gelöst haben will.
  Trigger: "fix issue", "setz das Issue um", "bearbeite Issue #NN in <repo>", eine github.com-Issue-URL,
  "/gh-issue". Erfasst das Issue inkl. Verlinkungen, reproduziert, findet die Ursache, implementiert Fix
  bzw. Feature, lässt die Tests mitwachsen, verifiziert gegen einen real laufenden Stand, erstellt den PR
  und merged selbst (squash) inkl. Cleanup. Schwester-Skill zu edp-issue; beide teilen den Ablauf-Core.
argument-hint: "[issue-url-oder-repo#nummer]"
---

# GitHub-Issue in einem privaten Repo autonom lösen

Voll autonom bis **gemergt** und lokal wie remote sauber. Meldet sich vorher nur
bei einem echten Blocker.

## Voraussetzungen

- Tools: `gh`, `git`

Per `requirement-checker` validieren, bei Fehlschlag abbrechen.

## Ablauf

**Lies `~/.claude/skills/.shared/issue-workflow-core.md` und folge Schritt 1–8.**
Dieser Skill füllt dessen Hooks. Nichts aus dem Core hier wiederholen.

---

## Profil

### `«HOST»` — github.com

`gh -R TimRudorf/<repo>` **mit `GH_HOST=github.com` vorweg**. `gh` ist auf diesem
Setup primär für die GHE-Instanz konfiguriert; ohne die Variable landen Aufrufe je
nach Kontext auf dem falschen Host.

Zickt `gh` beim Schreiben (`pr create`/`merge`) trotzdem: REST-API mit
`$GH_PRIVATE_TOKEN` als Fallback statt lange mit der Auth zu kämpfen.

Issue-Referenz aus `$ARGUMENTS`: volle URL, `<repo>#<nr>` oder blanke Nummer plus
Repo aus dem cwd.

### `«TICKET»` — keins

Alles Fachliche steht im Issue und seinen Verlinkungen. Zammad und die
`/zammad-*`-Skills sind hier nicht im Spiel.

### `«CHECKOUT»` — `~/dev/<repo>`

Fehlt der Klon: `GH_HOST=github.com gh repo clone TimRudorf/<repo> ~/dev/<repo>`.

⚠️ **Namensfalle:** Ein Verzeichnis, das wie das Repo heisst, ist nicht zwingend
das Repo. `~/dev/docker-compose/eintracht/` ist der **Compose-Stack** im Repo
`docker-compose`, nicht der Quellcode von `TimRudorf/Eintracht`. Vor der ersten
Änderung `git remote -v` im Zielverzeichnis gegen das Ziel-Repo halten.

### `«STATUS-SIGNAL»` — Assignee

Die Repos tragen nur die GitHub-Standard-Labels; es gibt kein `status:*`-Schema.
**Keine neuen Label-Schemata erfinden**, Bearbeitungssignal ist der Assignee:

```bash
GH_HOST=github.com gh issue edit <nr> -R TimRudorf/<repo> --add-assignee @me
```

### `«BRANCH»` — Default-Branch abfragen, nie annehmen

```bash
GH_HOST=github.com gh repo view TimRudorf/<repo> --json defaultBranchRef -q .defaultBranchRef.name
```

Die Repos sind uneinheitlich (`main`, `master`, `dev`) **und ändern sich** — jede
Aufzählung hier würde veralten, deshalb steht keine da. Auch der lokale Klon kann
auf einem Branch stehen, den es remote nicht mehr gibt: nach `fetch --prune`
prüfen, ob der aktuelle Branch noch ein Gegenstück hat.

Eine Branch-Angabe im Issue ist eine Behauptung — Issues leben länger als
Branches. Gegen `gh repo view` und die repo-eigene Doku prüfen; bei Abweichung
gilt der gemessene Stand, und die Entscheidung gehört als Kommentar ins Issue.

Feature-Branch `fix/<slug>` bzw. `feat/<slug>` von `origin/<default>`. Keine
Cascade — ein Ziel-Branch, ein PR. Hängt das Repo auf einem fremden Branch:
stashen, frisch branchen, poppen — nie auf Tims halbfertigem Topic huckepack.

### `«ENCODING»` — UTF-8

Durchgängig UTF-8, echte Umlaute. Kein Win-1252-Sonderfall.

### `«TESTS»` — repo-eigener Standard, erst lesen

Testkommando **aus dem Repo ableiten**, nicht raten: `package.json`-Scripts,
`.github/workflows/*`, `Makefile`, `*.csproj`, `pyproject.toml`. Gibt es noch
keine Suite, die erste mit dem Fix anlegen — nicht überspringen.

**Erste Suite in einem TS-Repo — vier Fallen:**

- Tests dürfen **nicht in den Produktions-Build** geraten. Eigene
  `tsconfig.test.json` mit separatem `outDir`, `*.test.ts` im Basis-`tsconfig.json`
  ausschliessen, danach einmal `rm -rf dist && <build>` und die Ausgabe ansehen.
- `node --test <verzeichnis>` scheitert — es braucht ein **gequotetes Glob-Muster**:
  `node --test "dist-test/**/*.test.js"`.
- **Leerer Glob = Exit 0.** Ein `npm test` ohne gefundene Testdatei ist grün. Eine
  Wache davorschalten, die abbricht und sagt, was fehlt.
- **Eine zählende Wache ist zu wenig.** Sie muss **jede** Testquelle im Workspace
  gegen das tatsächlich Gebaute halten und die fehlende Datei benennen. „Mindestens
  eine `.test.js` da" geht schief, sobald `tsconfig.test.json` eine explizite
  `files`-Liste führt.

### `«VERIFY»` — gegen einen real laufenden Stand

Grüne Unit-Tests sind **kein** E2E-Beleg.

1. **Repo hat ein Deploy-Ziel** → dorthin ausrollen und live prüfen. Eintracht:
   Stack `eintracht` auf der Debian-VM, Web-UI `http://172.16.0.3:3010`, Build
   lokal aus `/opt/data/eintracht`. UI-Prüfung per `/playwright-cli`.
2. **Kein Deploy-Ziel** → lokal real hochfahren (`docker compose up --build`,
   Dev-Server) und den echten Durchlauf fahren.

Geht beides nicht: transparent melden statt schwächer zu prüfen.

🔴 **Vor dem ersten Verifikationslauf den Bestand sichern**, wenn die Änderung
Daten löschen kann (neue DELETE-Pfade, Migrationen, `ON DELETE CASCADE`). Beim
Eintracht-Stack ist das die SQLite-Datei im Volume `data`; das Sicherungskommando
aus der Compose-Definition ableiten.

**Vergleichsmessung gegen den Stand vor der Änderung:** zuerst prüfen, ob das
Deploy-Ziel noch auf dem Default-Branch läuft — dann ist es selbst die Baseline
und der Fehler lässt sich dort direkt messen, bevor der Branch ausgerollt wird.
Das ist der belastbarste Beleg: echter Code, echte Daten, nichts rekonstruiert.

Nur wenn das nicht geht: `git worktree add <pfad> origin/<default> --detach` —
**nie** eine Kopie der Quellen ausserhalb des Repos. Dort fehlen `package.json`
und `node_modules`; der Build kippt still in ein anderes Modulsystem, der Prozess
stirbt aus einem anderen Grund als dem erwarteten, und das sieht wie eine
bestätigte Baseline aus. Worktree danach entfernen.

### `«PR»` — schlicht, Standard-Labels

`/edp-pull-request` ist GHE-/Zammad-spezifisch und hier **nicht** zu verwenden.

```bash
GH_HOST=github.com gh pr create -R TimRudorf/<repo> --base <default> --title "…" --body "…"
```

Body: `## Summary` + `## Test plan` (inkl. Verifikations-Beleg) und `Closes #<nr>`.
Label nur aus dem vorhandenen Standard-Satz (`bug`, `enhancement`,
`documentation`) — die `merge:*`/`todo:*`-Schemata der Arbeits-Repos gibt es hier
nicht. Kein Reviewer, kein Assignee-Zwang.

### `«ABSCHLUSS»` — selbst mergen und aufräumen

Merge-ready reicht **nicht**. Ohne Rückfrage:

```bash
GH_HOST=github.com gh pr merge <nr> -R TimRudorf/<repo> --squash --delete-branch
git checkout <default> && git pull --ff-only && git branch -D <feature> && git fetch --prune
```

Danach verifizieren: Issue wirklich geschlossen (`Closes` greift nur beim Merge in
den Default-Branch, sonst manuell schliessen mit Abschluss-Kommentar), Working
Tree sauber, kein verwaister Branch. Lief das Repo vorher auf einem fremden
Branch: dorthin zurückwechseln. Erst dann der Report.

### `«TABUS»`

- **Keine echte Aussenwirkung beim Verifizieren.** In Eintracht: den Worker-Cron
  **nie** starten und keinen Ticketkauf real auslösen — der Cron legt Tickets
  automatisch in den Warenkorb und wird bewusst nur von Tim im UI gestartet.
  Analog sonst: keine echten Mails, Pushes, Bestellungen. Solche Pfade mit
  Testdaten/Dry-Run prüfen oder die Prüflücke offen benennen.
- **Keine Secrets** ins Repo, Issue oder in den PR-Body — im Text nur der
  Variablenname.
- **Kein Force-Push**, kein Direkt-Commit auf den Default-Branch.
- **Git-Identity nie überschreiben** (global `Tim Rudorf <tim@rudorf.me>`).
- Ist das Ziel-Repo **public** (`dotfiles`, `arch-setup`): keine internen Pfade
  oder Verweise auf den eigenen Apparat in Issue-/PR-Text.

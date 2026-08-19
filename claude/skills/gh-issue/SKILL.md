---
name: gh-issue
description: >-
  Autonomer End-to-End-Orchestrator für ein GitHub-Issue in Tims eigenen Repos unter github.com/TimRudorf
  (Eintracht, n8n, wachalarm, tetra-decode, docker-compose, dotfiles, …). Nutzen, wenn Tim eine Issue-URL,
  ein `Repo#Nummer` oder eine Nummer aus einem seiner privaten Repos übergibt und sie gelöst haben will.
  Trigger: "fix issue", "setz das Issue um", "bearbeite Issue #NN in <repo>", eine github.com-Issue-URL,
  "/gh-issue". Versteht das Issue inkl. aller Verlinkungen, reproduziert Bugs, findet die Ursache,
  implementiert Fix bzw. Feature, lässt die Tests mitwachsen, verifiziert gegen einen real laufenden Stand,
  erstellt den PR, treibt CI + lokales Review und merged selbst (squash) inkl. Cleanup. Schwester-Skill zu
  edp-issue für Arbeits-Repos auf GHE — beide teilen sich denselben Ablauf-Core.
argument-hint: [issue-url-oder-repo#nummer]
---

# GitHub-Issue in einem privaten Repo autonom lösen

Orchestrator vom Issue bis zum gemergten PR. **Voll autonom** — meldet sich erst zurück, wenn gemergt und
lokal wie remote sauber ist (oder ein echter Blocker eine Entscheidung von Tim braucht).

## Voraussetzungen

- Tools: `gh`, `git`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Ablauf

**Lies `~/.claude/skills/.shared/issue-workflow-core.md` und folge dessen Schritten 1–8.** Dieser Skill ist
das **Profil** dazu: er füllt die Hooks des Cores. Nichts aus dem Core hier wiederholen.

## Profil

### `«HOST»` — github.com

- `gh -R TimRudorf/<repo>` mit **`GH_HOST=github.com`** vorweg. `gh` ist auf diesem Setup primär für die
  GHE-Instanz konfiguriert; ohne die Variable landen Aufrufe je nach Kontext auf dem falschen Host.
- Zicken `gh` beim Schreiben (`pr create`/`merge`) trotzdem herum: REST-API mit `$GH_PRIVATE_TOKEN` als
  verifizierter Fallback — Befehle in [[tim/feedback/private-repos-auto-roundtrip]]. Nicht lange mit
  `gh`-Auth kämpfen.
- Issue-Referenz aus `$ARGUMENTS`: volle URL, `<repo>#<nr>` oder blanke Nummer + Repo aus dem cwd.

### `«TICKET»` — keins

Kein vorgelagertes Ticket-System. Alles Fachliche steht im Issue und seinen Verlinkungen. Zammad,
`EDP#`-Nummern und `/zammad-*`-Skills sind hier **nicht** im Spiel.

### `«CHECKOUT»` — `~/dev/<repo>`

Fehlt der Klon: `GH_HOST=github.com gh repo clone TimRudorf/<repo> ~/dev/<repo>`.

> ⚠️ **Namensfalle:** Ein Verzeichnis, das wie das Repo heißt, ist nicht zwingend das Repo. Beispiel:
> `~/dev/docker-compose/eintracht/` ist der **Compose-Stack** im Repo `docker-compose`, **nicht** der
> Quellcode von `TimRudorf/Eintracht`. Vor der ersten Änderung immer `git remote -v` im Zielverzeichnis
> prüfen und gegen das Ziel-Repo abgleichen.

### `«STATUS-SIGNAL»` — Assignee

Die Repos tragen nur die GitHub-Standard-Labels, es gibt kein `status:*`-Schema. Bearbeitungssignal ist
daher der Assignee — **keine neuen Label-Schemata erfinden**:

```bash
GH_HOST=github.com gh issue edit <nr> -R TimRudorf/<repo> --add-assignee @me
```

### `«BRANCH»` — Default-Branch ermitteln, nie annehmen

**Den Default-Branch aktiv abfragen**, nicht raten:

```bash
GH_HOST=github.com gh repo view TimRudorf/<repo> --json defaultBranchRef -q .defaultBranchRef.name
```

Die Repos sind uneinheitlich (`main`, `master`, `dev` kommen alle vor) **und sie ändern sich** — jede
Aufzählung an dieser Stelle veraltet, deshalb steht hier keine. Nie aus dem Gedächtnis, immer abfragen.
Auch der lokale Klon kann auf einem Branch stehen, den es remote längst nicht mehr gibt: nach dem
`fetch --prune` prüfen, ob der aktuelle Branch überhaupt noch ein Gegenstück hat.

**Eine Branch-Angabe im Issue ist eine Behauptung, kein Fakt.** Issues leben länger als Branches. Nennt
das Issue einen Ziel-Branch, gegen `gh repo view` und die repo-eigene Doku (`CLAUDE.md`, `README`)
gegenprüfen; bei Abweichung gilt der gemessene Stand, und die Entscheidung gehört als Kommentar ins
Issue — sonst rätselt der nächste, warum der PR woanders hinzeigt.

Feature-Branch `fix/<slug>` bzw. `feat/<slug>` **von `origin/<default>`** ableiten. Keine Branch-Cascade —
ein Ziel-Branch, ein PR. Hängt das Repo gerade auf einem fremden Branch: eigene Änderung stashen, frisch von
`origin/<default>` branchen, stash poppen — nie auf Tims halbfertigem Topic huckepack
([[tim/feedback/private-repos-auto-roundtrip]]).

### `«ENCODING»` — UTF-8

Durchgängig UTF-8, echte Umlaute ([[tim/feedback/umlauts]]). Kein Win-1252-Sonderfall in diesen Repos.

### `«TESTS»` — repo-eigener Standard, erst lesen

Testkommando **aus dem Repo ableiten**, nicht raten: `package.json`-Scripts, `.github/workflows/*`,
`Makefile`, `*.csproj`, `pyproject.toml`. Typisch: TypeScript/Next.js → `npm test`, `npm run lint`,
`npm run typecheck`; C# → `dotnet test`; Python → `pytest`. Gibt es noch keine Suite, die erste mit dem
Fix anlegen — nicht überspringen ([[tim/feedback/tests-dynamisch-erweitern]]).

**Beim Anlegen der ersten Suite in einem TS-Repo vier Fallen:**

- Tests dürfen **nicht in den Produktions-Build** geraten, sonst landen sie im Image. Eigene
  `tsconfig.test.json` mit separatem `outDir`, und `*.test.ts` im Basis-`tsconfig.json` ausschließen.
  Danach einmal `rm -rf dist && <build>` und die Ausgabe wirklich ansehen.
- `node --test <verzeichnis>` scheitert (wird als Datei interpretiert) — es braucht ein **gequotetes
  Glob-Muster**: `node --test "dist-test/**/*.test.js"`.
- **Leerer Glob = Exit-Code 0.** Ein `npm test`, das keine Testdatei findet, ist grün. Ohne CI merkt das
  niemand → eine Wache davorschalten, die abbricht und sagt, was fehlt und wie man es behebt
  ([[tim/feedback/pruefungen-muessen-sich-selbst-erklaeren]]).
- **Eine zählende Wache ist zu wenig.** Sie muss **jede** Testquelle im Workspace mit dem tatsächlich
  Gebauten abgleichen und die fehlende Datei benennen. „Mindestens eine `.test.js` da" geht schief,
  sobald die `tsconfig.test.json` eine explizite `files`-Liste führt: die nächste Testdatei wird nie
  kompiliert, nie ausgeführt — und die Wache meldet weiterhin grün.

### `«VERIFY»` — gegen einen real laufenden Stand

Grüne Unit-Tests sind **kein** E2E-Beleg ([[tim/feedback/code-self-check-vor-review]]). Zwei Fälle:

1. **Repo hat ein dokumentiertes Deploy-Ziel im Vault** → dorthin ausrollen und live prüfen.
   Eintracht: Stack `eintracht` auf der Debian-VM, Web-UI `http://172.16.0.3:3010`, Build lokal aus
   `/opt/data/eintracht` — Ablauf, Env und Bau-Gotchas stehen vollständig in
   `$VAULT/referenz/eintracht-ticketapp.md`. UI-Prüfung per `/playwright-cli`.
2. **Kein Deploy-Ziel** → lokal real hochfahren (`docker compose up --build`, Dev-Server) und den echten
   Durchlauf fahren, nicht nur den Unit-Test.

Geht beides nicht, transparent melden statt schwächer zu prüfen (Core Schritt 6).

**Vor dem ersten Verifikationslauf den Bestand sichern**, wenn die Änderung Daten löschen kann (neue
DELETE-Pfade, Migrationen, `ON DELETE CASCADE`). Beim Eintracht-Stack ist das die SQLite-Datei im Volume
`data`; das Kommando steht in `$VAULT/referenz/eintracht-ticketapp.md`.

**Vergleichsmessung gegen den Stand vor der Änderung** (Beweis, dass der Fehler vorher wirklich auftrat):
**zuerst prüfen, ob das Deploy-Ziel noch auf dem Default-Branch läuft** — dann ist es selbst die Baseline
und der Fehler lässt sich dort direkt messen (ein `curl` gegen den laufenden Dienst), bevor der Branch
ausgerollt wird. Das ist der belastbarste Beleg überhaupt: echter Code, echte Daten, nichts rekonstruiert.
Nur wenn das nicht geht, über `git worktree add <pfad> origin/<default> --detach` — **nie** über eine Kopie der Quellen in
ein Verzeichnis außerhalb des Repos. Außerhalb fehlen `package.json` und `node_modules`; der Build kippt
dann still in ein anderes Modulsystem oder findet seine Abhängigkeiten nicht, und der Prozess stirbt aus
einem ganz anderen Grund als dem erwarteten. Das sieht wie eine bestätigte Baseline aus und ist keine
([[tim/feedback/urteil-braucht-vollstaendige-messung]]). Worktree danach wieder entfernen.

### `«WISSEN»` — Vault, bestehende Note zuerst

Neu gewonnenes Wissen in die **bestehende** SSoT ergänzen statt eine zweite anzulegen
([[tim/feedback/dry-vault-no-duplication]]): Betrieb/Deploy → `$VAULT/referenz/<thema>.md` (Eintracht:
`referenz/eintracht-ticketapp.md`), Architektur → `$VAULT/projekte/<repo>/architektur.md`
([[tim/feedback/coding-projekt-snapshots]]). Vault-Writes werden per Hook autocommittet.

### `«PR»` — schlicht, Standard-Labels

`/edp-pull-request` ist GHE-/Zammad-spezifisch und hier **nicht** zu verwenden. Stattdessen:

```bash
GH_HOST=github.com gh pr create -R TimRudorf/<repo> --base <default> --title "…" --body "…"
```

Body: `## Summary` + `## Test plan` (inkl. des Verifikations-Belegs aus Schritt 6) und `Closes #<nr>`.
Label nur aus dem **vorhandenen** Standard-Satz (`bug`, `enhancement`, `documentation`) — die
`merge:*`/`todo:*`-Schemata der Arbeits-Repos gibt es hier nicht. Kein Reviewer, kein Assignee-Zwang.

### `«ABSCHLUSS»` — selbst mergen und aufräumen

Merge-ready reicht **nicht** — der Vorgang ist erst fertig, wenn gemergt und alles sauber ist
([[tim/feedback/private-repos-auto-roundtrip]]). Ohne Rückfrage:

```bash
GH_HOST=github.com gh pr merge <nr> -R TimRudorf/<repo> --squash --delete-branch
git checkout <default> && git pull --ff-only && git branch -D <feature> && git fetch --prune
```

Danach verifizieren ([[tim/feedback/schreib-verify]]):
- Issue wirklich geschlossen? `Closes` greift nur beim Merge in den Default-Branch — sonst manuell
  schließen mit Abschluss-Kommentar ([[tim/feedback/pr-issues-auto-schliessen]]).
- Working Tree sauber, kein verwaister Branch, kein untracked Rest ([[tim/feedback/repos-immer-clean]]).
- Lief das Repo vorher auf einem fremden Branch: dorthin zurückwechseln.

Erst dann der Report (Core 8e).

### `«TABUS»`

- **Keine echte Außenwirkung beim Verifizieren.** In Eintracht heißt das konkret: den Worker-Cron **nie**
  starten und keinen Ticketkauf/Warenkorb-Pfad real auslösen — der Cron legt Tickets automatisch in den
  Warenkorb und wird bewusst nur von Tim im UI gestartet (`$VAULT/referenz/eintracht-ticketapp.md`).
  Analog in anderen Repos: keine echten Mails, Pushes, Bestellungen oder Kunden-Requests. Solche Pfade
  mit Testdaten/Dry-Run prüfen oder die Prüflücke offen benennen.
- **Keine Secrets ins Repo, ins Issue oder in den PR-Body.** Werte aus `.env`/`/opt/stacks/*/.env` bleiben
  draußen; im Text nur der Variablenname.
- **Kein Force-Push**, kein Direkt-Commit auf den Default-Branch.
- **Git-Identity nie überschreiben** — global gilt `Tim Rudorf <tim@rudorf.me>`; kein
  `-c user.name`/`-c user.email` am Commit ([[tim/feedback/git-author-arbeit-repos]]).
- Ist das Ziel-Repo **public** (`dotfiles`, `arch-setup`): keine internen Pfade oder Vault-Verweise in
  Issue-/PR-Text tragen, Sachgrund inline formulieren.

Abschließend `skill-optimize` mit `gh-issue` aufrufen.

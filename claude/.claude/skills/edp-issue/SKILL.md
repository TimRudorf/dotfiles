---
name: edp-issue
description: >-
  Autonomer End-to-End-Orchestrator für ein GHE-EDP-Issue (Bug oder Feature). Nutzen, wenn Tim eine
  GHE-Issue-Nummer oder -URL (z.B. https://einsatzleitsoftware.ghe.com/edp/edpweb/issues/369) übergibt
  und sie gelöst haben will. Trigger: "fix issue", "setz das Issue um", "bearbeite Issue #NN",
  "lös das Ticket im Repo", eine edp-GHE-Issue-URL oder -Nummer, "/edp-issue". Erfasst das Issue inkl.
  aller Verlinkungen (auch Zammad), reproduziert, findet die Ursache, implementiert Fix bzw. Feature,
  lässt die Tests mitwachsen, verifiziert auf der Dev-VM und treibt den PR bis zur Mergebarkeit.
argument-hint: "[issue-nummer-oder-url]"
---

# EDP-Issue autonom lösen

Läuft voll autonom bis der PR mergebar ist. Meldet sich vorher nur, wenn ein
echter Blocker eine Entscheidung von Tim braucht.

## Voraussetzungen

- Env: `EDP_PROJECT_ROOT`
- Tools: `gh`, `git`, `ssh`, `edp-ctrl`, `playwright-cli`

Per `requirement-checker` validieren, bei Fehlschlag abbrechen.

## Ablauf

**Lies `~/.claude/skills/.shared/issue-workflow-core.md` und folge Schritt 1–8.**
Dieser Skill ist das **Profil** dazu und füllt dessen Hooks mit den EDP-Fakten.
Nichts aus dem Core hier wiederholen.

---

## Profil

### `«HOST»` — GHE

`gh -R einsatzleitsoftware.ghe.com/edp/<repo>`. Issue-Referenz aus
`https://einsatzleitsoftware.ghe.com/edp/<repo>/issues/<nr>` oder blanker Nummer
plus aktuellem Repo.

⚠️ **`gh search issues` funktioniert auf dieser Instanz nicht** — es antwortet mit
`Invalid search query`, Exit 1, Meldung auf stderr. Wer stderr verwirft, bildet
Fehlschlag und Leermenge auf dieselbe Ausgabe ab. Für Bestandsprüfungen den
Bestand ziehen und lokal durchsuchen:

```bash
gh issue list -R einsatzleitsoftware.ghe.com/edp/<repo> --state all --limit 300 \
  --json number,title,state,body > /tmp/issues.json
jq -r '.[] | select((.title + " " + (.body//"")) | test("<begriff>";"i")) | "\(.number) [\(.state)] \(.title)"' /tmp/issues.json
```

### `«STATUS-SIGNAL»` — `status:active`

```bash
gh issue edit <nr> -R einsatzleitsoftware.ghe.com/edp/<repo> \
  --add-label "status:active" --remove-label "status:paused"
```

### `«TICKET»` — Zammad

Jede `EDP#<nr>` im Issue per `/zammad-read` auflösen, inkl. Kundenartikel und
Trigger-Beschreibung.

⚠️ **GHE-Bildanhänge sind SSO-gated**: `/user-attachments/assets/…` liefert per
`curl` die Login-HTML statt des Bildes. Screenshot-Inhalt nicht so beschaffen —
stattdessen den gemeldeten Zustand in der Dev-Umgebung reproduzieren.

### `«CHECKOUT»` — Worktree unter der EDP-Projektwurzel

🔴 **Eine Ebene mehr als üblich.** `edp-ctrl dev compile|test <projekt>` sucht
`<project-root>/<projekt>`. Ein flacher Worktree heisst nicht `<projekt>` und
wird nicht gefunden — dann greift der Vorgabewert `~/dev/EDP`, der Lauf misst den
Haupt-Klon und ist grün, ohne den Fix gesehen zu haben.

```bash
git worktree add ~/dev/EDP/.worktrees/<vorgang>/<repo> -b <branch> origin/dev
edp-ctrl dev test <repo> --project-root ~/dev/EDP/.worktrees/<vorgang>
```

Der Ausgabekopf jedes `compile`/`test` nennt Branch **und** Commit — vor jeder
Beweisführung gegenlesen.

⚠️ Der Haupt-Klon hängt oft Wochen zurück. Deshalb aus `origin/dev` abzweigen und
vor jedem Edit den **Pfad** prüfen, nicht den Repo-Namen: beide Verzeichnisse
heissen `<repo>` und sehen im Prompt gleich aus.

### `«BRANCH»` — alles landet auf `dev`

🔴 **Arbeit in EDP-Repos geht gegen `dev`.** Promotion nach `beta`/`release` ist
eine Release-Entscheidung des Teams — kein selbst eröffneter Kaskaden-PR. Das
gilt auch, wenn der Issue-Body eine fertige `## Branch & Cascade`-Sektion mit
anderer Vorgabe trägt.

Die Fall-A–D-Bestimmung bleibt nützlich für die Frage *wo sitzt der Defekt* (und
gehört in den Bericht), nicht für die Frage *wohin geht der PR*.

Vor allem anderen den Default-Branch messen — ein Einzeiler, der eine falsche
Issue-Angabe sofort aufdeckt:

```bash
gh api "repos/edp/<repo>" --hostname einsatzleitsoftware.ghe.com -q .default_branch
```

⚠️ Auch die **Richtung** einer vorhandenen Cascade-Angabe gegenprüfen:
`auto-cascade.yml` zieht nach **oben** (`release` → `beta` → `dev`, dev =
Endstation). `dev` → `beta` → `release` ist Promotion, keine Kaskade. Welche
Kanäle es gibt, mit `git branch -r` selbst erheben.

Berührt ein Vorgang mehrere Repos, je Repo eigener Branch und PR — und die
Merge-Reihenfolge ausdrücklich festhalten.

### `«ENCODING»` — pro Repo messen

🔴 **„Delphi = Win-1252" ist eine Annahme.** `edp/schn_ivena` führt seine
Delphi-Quellen als **UTF-8 mit BOM**; die CI-Stufe `delphi / encoding` erzwingt
das. Wer dort blind `iconv -f WINDOWS-1252` anwendet, kodiert doppelt.

```bash
file -b <datei>                     # "UTF-8 (with BOM)" vs. "ISO-8859"/"Non-ISO extended-ASCII"
git log --oneline -- <datei> | head # eine Encoding-Umstellung steht als eigener Commit drin
```

Regelfall sonst: Windows-1252 bei `.pas`/`.dpr`/`.dpk`/`.inc`/`.dfm`, UTF-8 im
Frontend. Nach jedem Edit auf U+FFFD prüfen.

🔴 **Zeilenenden gehören mitgemessen.** IDE-Dateien (`.dproj`, `.dfm`,
`.groupproj`) tragen CRLF, auch ohne `.gitattributes`. Ein Werkzeug im Textmodus
dreht die ganze Datei still auf LF — der Inhalt stimmt, der Diff ist Unsinn.
Solche Dateien byte-genau schreiben (`'wb'`, `\r\n`) und gegenlesen:

```bash
git diff --stat origin/<base> -- <pfad>   # zwei Zeilen Edit = zwei Zeilen Diff
```

### Versionsnummer — erst messen, wer versioniert

🔴 **Nicht von Hand bumpen, ohne den zentralen Schalter geprüft zu haben.** In den
`schn_*`-Repos steht in der repo-eigenen `delivery.yml` bewusst **kein**
`version-bump`; maßgeblich ist der Default des gerufenen Workflows:

```bash
gh api --hostname einsatzleitsoftware.ghe.com -H "Accept: application/vnd.github.raw" \
  "repos/edp/.github/contents/.github/workflows/delivery.yml?ref=dev" | grep -A14 'version-bump:'
```

Steht dort `true`, vergibt die Pipeline den Tag und injiziert die Version beim
Bau. Ein Hand-Bump erzeugt dann eine Nummer, die einem **früheren** Release
entspricht. Gegenprobe: `git tag --sort=-v:refname | head -3` gegen den `.dproj`-Wert.

Nur wenn `version-bump` fehlt oder `false` ist, gilt manuelles SemVer — dann die
numerischen `VerInfo_Release`-Felder **und** den `FileVersion=`-String in allen
Release-Configs synchron. Kein Bump bei Doku/Test/CI.

⚠️ `git add` als **eigenen** Aufruf ausführen — in `git add -A && git commit` sieht
der Guard-Hook noch nichts Gestagtes und schweigt.

### `«TESTS»` — DUnitX

`edp-ctrl dev test <repo> --project-root <worktree-eltern>`. Go = `go test`,
Frontend = Repo-Standard.

- **Assert-Meldungen ASCII halten.** Die Suite ist eine Konsolenanwendung; Umlaute
  kommen im CI-Log als Ersatzzeichen an. Kommentare behalten echte Umlaute, und
  **Datenliterale** (Testdaten, erwartete Fremdtexte) bleiben unangetastet.
- **Neue Testunit in `.dpr` UND `.dproj`.** Der `.dproj`-Eintrag allein linkt
  nichts — der Bau folgt der `uses`-Liste des `.dpr`. Deshalb je Lauf die
  **erwartete Testanzahl** mitführen; sonst merkt niemand, dass eine Prüfung
  gar nicht mitlief.
- **Rot heisst trotzdem: es muss übersetzen.** Die API-Fläche (Record, Signatur,
  Verdrahtung durch Factory) gehört mit in Commit 1, das Verhalten nicht.
  Private Hilfsmethoden ans **Ende** der Klassensektion (sonst `E2169`).
- `Tests Failed` **plus** `Tests Errored` ist die Rot-Zahl; DUnitX zählt
  Ausnahmen getrennt.

#### Nicht linkbare Units

Ist der Defekt ein fehlender Aufruf in einer Unit, die das Testprojekt nicht
linkt (`UfrmMain`, `core_form`, `mdlEinsatz`), ist eine **Quellprüfung** der
einzige Test, der ihn fassen kann. Muster: `tests/unit/Test.Source.*.pas` mit den
Helfern aus `Test.Source.Quelltext`.

- Ausschnitt an der **Funktionsgrenze** (`RumpfVon`), nicht über ein Abstandsfenster.
- Jede Prüfung braucht eine **Schärfe-Selbstprobe**: Ausschnitt nicht leer, Nachbar
  nicht enthalten, Untergrenze erreicht.
- 🔴 **Den richtigen Schneider wählen.** `CodeOhneKommentareUndTexte` maskiert
  Textliterale, `CodeOhneKommentare` lässt sie stehen. Wer einen Parameternamen
  oder Spaltennamen im maskierten Ausschnitt sucht, sucht in Leerzeichen — die
  Prüfung ist dauerhaft rot und misst nichts.
- Zusicherungen auf **Reihenfolge** statt auf blosses Vorkommen, wo die Reihenfolge
  die Wirkung trägt (Prüfung vor `EnqueueAufgabe`, `EXIT` dazwischen).

#### Mutationsprobe

Jede neue Schutzmaßnahme einmal gezielt kaputtmachen und belegen, dass sie rot
wird. Werkzeug: **`scripts/mutationsprobe.py`** in diesem Skill-Verzeichnis
(Fallliste oben in der Datei anpassen) — es fährt die Reihe seriell gegen die
Dev-VM und prüft je Fall, dass die Mutation den Baum wirklich verändert hat,
dass der Push serverseitig angekommen ist, dass die Testanzahl stimmt und dass
**genau die erwarteten Testnamen** rot sind.

Pflichtbestandteile jeder Reihe:

| Fall | Wozu |
|---|---|
| **Baseline** (unverändert) | ohne sie meldet jede Mutation „greift", wenn die Vorrichtung selbst rot ist |
| **Gegenrichtung** (harmlose Änderung) | fängt zu scharfe und flakey Prüfungen |
| **Verdrahtungsprobe** (Testunit aus dem `.dpr`) | belegt, dass die Testanzahl trägt |

🔴 **`edp-ctrl dev test` pusht den Branch selbst.** Ein bewusst nur lokal
gehaltener Fix-Commit wird damit mitgepusht, und der „rote" Lauf misst den Fix.
Den roten Lauf deshalb messen, **bevor** der Fix lokal existiert.

🔴 **Je Reihe einen frischen Wegwerf-Zweig** (`tmp/<vorgang>-mutN`). Ein
wiederverwendeter Name liegt auf `origin` noch auf dem alten Stand, der Push wird
still als non-fast-forward abgewiesen, und jeder Fall misst den Vorgänger.
`tmp/**` löst weder `ci.yml` noch `delivery.yml` aus. Danach lokal und auf
`origin` löschen.

⚠️ Nach einem **abgebrochenen** Lauf bleibt `<Repo>Tests.exe` auf der VM stehen und
blockiert jeden weiteren Lauf. Erst prüfen, dann deuten:

```bash
ssh "$(edp-ctrl config get vm-host)" 'tasklist /FI "IMAGENAME eq <Repo>Tests.exe"'
ssh "$(edp-ctrl config get vm-host)" 'taskkill /F /PID <pid>'
```

🔑 Läuft parallel ein Review-Agent, die Reihe in einem **zweiten** Worktree fahren
— sie schaltet Branches um und schreibt in die Quellen.

### `«VERIFY»` — ausschliesslich Dev-VM

🔴 **Das SSH-Ziel kommt aus `edp-ctrl config get vm-host`, nicht aus
`$EDP_VM_HOST`.** Die Variable trägt den Maschinennamen und ist als SSH-Ziel
unbrauchbar; `ssh $EDP_VM_HOST` scheitert und sieht nach toter VM aus.

**Die VM ist exklusiv zu belegen.** `compile`, `test` und `service` erst nach
gesetztem `C:\vm.lock`. Die erste verändernde Aktion an das **Ergebnis** des
check-and-set binden, nicht bloss dahinterschreiben — der Lock kann auch mitten im
Lauf den Halter wechseln. Alle Messungen im eigenen Lock-Fenster abschliessen;
nach der Freigabe misst man fremden Code.

- `dev compile` baut **und** bounct den Dienst. `dev test` tut das **nicht** — wer
  danach Live-Log oder Datenbank misst, misst den Vorgänger.
- `--platform Win64` nicht mehr von Hand setzen (Default seit edp-ctrl v0.2.0).
- Ein Testprojekt braucht kein vorheriges `compile`, solange es seine Quellen
  selbst übersetzt (eigener `DCC_DcuOutput`) — an der `.dproj` ablesen.

**Ein gescheiterter `dev compile` heisst nicht „nichts messbar".** Drei Schritte,
bevor daraus ein Blocker wird: gegen die unveränderte Baseline gegenprüfen
(zeilengleicher Fehler = vorbestehend); prüfen, was trotzdem läuft (ein Bau
scheitert an einer Unit, alles was sie nicht linkt übersetzt weiter); und die
Ursache **direkt** messen (`dir`/`if exist` auf der VM) statt sie aus zwei
Fehlermeldungen zu erschliessen.

Datenbank lesend über `/edp-database` (mysql.exe auf der Dev-VM). Lesende Queries
brauchen keinen Lock, schreibende schon.

⚠️ **Dev-VM ≠ Build-VM.** Die CI-Build-VM `edpttz-svghr01` hängt hinter dem
edp-OpenVPN mit YubiKey-PIN und ist autonom **nicht** erreichbar. Ist der
Gegenstand die Bau-Engine, wird offline hart belegt (`.dproj`-Ausgabepfade, Pins,
Trees-API am gepinnten SHA) und im PR ausgewiesen, was dieser PR nicht prüfen kann.

**Repos ohne Dev-VM-Deploy** (`edp/installer`, `edp/.github`,
`edp/edp-runtime-redist`): die reale Umgebung ist der CI-Runner am PR. Zusätzlich
taugt die Dev-VM als **Windows-PowerShell-5.1-Prüfstand** (die CI fährt pwsh 7) —
per `scp` nach `C:\Windows\Temp`, berührt das Projektverzeichnis nicht und braucht
deshalb **keinen** Lock. Ausgabe in eine Datei schreiben und zurücklesen, die
Konsole über SSH hat eine fremde Codepage.

Nennt ein Akzeptanzkriterium ein Kommando, dieses vor dem Ausführen gegen das
Skript prüfen — Parameternamen und Mechanismen im Issue sind Messungen von damals.
Ist es wörtlich nicht erfüllbar, die gemeinte Fassung ausführen und die Lesart in
Issue und PR begründen.

### `«PR»` — `/edp-pull-request`, dieses Profil gewinnt

⚠️ Jener Skill sagt „keine Labels" und will den Entwurf bestätigt haben — beides
ist hier überholt: Labels sind Pflicht, im Autonomie-Modus entfällt die
Zwischenbestätigung. Seine Zammad-Notiz greift nur bei echtem `EDP#<nr>` im Body.

**Genau ein `merge:*`** nach dem dominanten Änderungsmotiv:

| Label | Wofür |
|---|---|
| `merge:bug` | Fehler in vorhandener Funktion (Standardfall) |
| `merge:feature` | Erweiterung einer vorhandenen Funktion |
| `merge:core-feature` | neue grosse Funktion / grosse Überarbeitung |
| `merge:design/usability` | reine Bedienbarkeit ohne neue Funktion |
| `merge:refactoring` | Umbau ohne Funktionsänderung |
| `merge:tests` | ausschliesslich neue Tests |
| `merge:documentation` | nur Doku |

⚠️ Das ist der gemeinsame Nenner. Einzelne Repos führen mehr (z.B.
`merge:ci/workflows`); die Definitionsquelle ist `.github/labels.yml` des Repos.
Nicht den ähnlichsten alten PR kopieren — Labels kommen später dazu als die PRs,
die sie gebraucht hätten.

**`todo:review`** praktisch immer. **`todo:testing`** nach genau einer Prüffrage:
*entsteht der offene Nachweis von allein, sobald die Anlage läuft?* Nein → dran,
egal wie harmlos die Änderung aussieht.

**Kein Copilot** — der Bot ist auf der Instanz inaktiv, `--add-reviewer` ein
stiller No-op.

#### CI lesen

- Labels **unmittelbar** nach dem Erstellen setzen: der erste `Merge-Label`-Lauf
  startet ohne sie und ist erwartungsgemäß rot. Er heilt sich selbst; ein
  abgebrochener Lauf kann den PR aber auf `UNSTABLE` stehen lassen, obwohl alles
  grün ist — dann gezielt `gh run rerun` auf den `cancelled`-Lauf.
- Der Aggregat-Check heisst **nicht überall** `ci-summary` (in `edp/.github`:
  `repo-summary`). Aus dem Repo ablesen, nicht annehmen. Auf eine Bedingung warten,
  die ihn **nennt** — direkt nach einem Push ist `gh pr checks` unvollständig und
  eine „alles fertig"-Prüfung trivial erfüllt.
- 🔴 **Ein grünes `ci-summary` belegt nicht, dass Tests liefen.** Die DUnitX-Suite
  läuft **innerhalb** von `delphi / build` und taucht als eigener Check nicht auf.
  Beleg ist allein das Job-Log:

```bash
gh run view <id> -R einsatzleitsoftware.ghe.com/edp/<repo> --log --job=<job-id> \
  | grep -aE 'RUN_TESTS|Führe Tests aus|Tests (Found|Passed|Failed)'
```

  Erwartet: `RUN_TESTS: true` und ein `Tests Found` grösser null. Der Auszug gehört
  in den PR-Body. ⚠️ Im Log gibt es keinen Schritt `Build` — der Hauptbau läuft
  unter `TestBuild`.
- **Der Format-Bot committet in den Feature-Branch.** Der nächste eigene Push wird
  dann abgewiesen: `git fetch` + `git rebase origin/<branch>`, **nicht** force-pushen.

### `«ABSCHLUSS»`

Definition of Done ist der **mergebare** Zustand. Den Merge macht das Team.

### `«TABUS»`

- Testen/Verifizieren/Reproduzieren **nur** in der Dev-Umgebung. Lokaler Build,
  lokales Harness oder „CI ist grün" sind kein Ersatz.
- Kein `gh workflow run delivery.yml` ohne anschliessende Waisen-Release-Kontrolle
  (`gh release list`, `<branch>-latest` mit `gh release delete --cleanup-tag` weg).
  Ein normaler Push auf `bugfix/**` baut nur — ob er veröffentlicht, steht im
  `publish:`-Ausdruck der repo-eigenen `delivery.yml`.
- Externer Kundenversand nur mit Freigabe und in Tims Duktus.
- Keine Verweise auf den eigenen Apparat in Issue-, PR-, Commit- oder Zammad-Text.
- Git-Author kommt aus der Repo-Config; nie `-c user.name`/`-c user.email`.

---

## Berührt das Issue eine Oberfläche

Dann ist `edp-frontend-design` verbindlich — auch bei „nur ein Feld ergänzen".
Nicht den generischen `frontend-design` direkt nutzen.

## Zwei Sessions am selben Vorgang

Der Skill läuft autonom im Hintergrund; eine zweite Session kann denselben Vorgang
halten.

- Ein leerer PR-Bestand ist eine Momentaufnahme. Lehnt `gh pr create` mit
  „already exists" ab, ist das die Abstimmung: den bestehenden PR übernehmen, nicht
  daran vorbei einen neuen Branch aufmachen.
- Der Worktree ist geteilt. Vor einem Branch-Wechsel darin ansagen, und ihn nicht
  über einen laufenden Review legen.
- Review-Agenten gegen den **serverseitigen** PR-Head beauftragen, nicht gegen „das
  Arbeitsverzeichnis" — ein Arbeitsverzeichnis kann während des Laufs wandern.
- Doppelte Review-Notizen zusammenführen, Randfunde nicht doppelt erfassen.

## Fremde Repos: erst lesen, dann schreiben

Berührt der Vorgang ein anderes Repo, dort **erst** den aktuellen Stand erheben
(`gh pr list --state open` **und** `gh issue list`), bevor kommentiert oder
angelegt wird — sonst schreibt man eine Analyse zu einer Frage, die dort längst
entschieden ist. Fremde PRs nicht anfassen, aber prüfen, ob sich der eigene
Vorgang durch sie erledigt hat.

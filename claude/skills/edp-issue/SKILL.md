---
name: edp-issue
description: >-
  Autonomer End-to-End-Orchestrator für ein GHE-EDP-Issue (Bug oder Feature). Nutzen, wenn Tim eine
  GHE-Issue-Nummer oder -URL (z.B. https://einsatzleitsoftware.ghe.com/edp/edpweb/issues/369) übergibt und
  sie gelöst haben will. Trigger: "fix issue", "setz das Issue um", "bearbeite Issue #NN", "lös das Ticket im
  Repo", eine reine edp-GHE-Issue-URL/-Nummer, "/edp-issue". Versteht das Issue inkl. aller Verlinkungen
  (auch Zammad), reproduziert Bugs automatisch, findet die Fehlerquelle, plant + implementiert den Fix bzw. das
  Feature nach den Git-/Branch-Cascade-Konventionen, ergänzt Tests, verifiziert end-to-end, hält Issue + Doku
  aktuell, erstellt den PR und treibt ihn über CI- und lokalen Review-Loop bis zur Mergebarkeit. Läuft voll
  autonom bis der PR mergebar ist und meldet erst dann zurück.
argument-hint: [issue-nummer-oder-url]
---

# EDP-Issue autonom lösen

Orchestrator vom GHE-Issue bis zum mergebaren PR. **Voll autonom** — meldet sich erst zurück, wenn der PR
theoretisch mergebar ist (oder ein echter Blocker eine Entscheidung von Tim braucht).

## Voraussetzungen

- Env: `EDP_PROJECT_ROOT` (Mac-Setup + Fallen: `$VAULT/referenz/edp-project-root-mac.md`)
- 🔴 **Das SSH-Ziel der Dev-VM NICHT aus `$EDP_VM_HOST` nehmen.** Die Var trägt den Maschinennamen
  (`vm-eifert-develop`) und ist als SSH-Ziel unbrauchbar — auf Poseidon kennt `~/.ssh/config` nur
  `eifert-dev`, und `ssh $EDP_VM_HOST` scheitert mit „Could not resolve hostname". Das sieht nach toter
  VM aus und ist ein Konfigurationsfehler. Maßgeblich ist **immer** `edp-ctrl config get vm-host`
  (Messung: `$VAULT/referenz/edp-devvm.md`).
- Tools: `gh`, `git`, `ssh`, `edp-ctrl`, `playwright-cli`
- Projekt: lokales EDP-Repo-Checkout (Pfad-Muster laut `$VAULT/referenz/edp-project-root-mac.md`)

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Ablauf

**Lies `~/.claude/skills/.shared/issue-workflow-core.md` und folge dessen Schritten 1–8.** Dieser Skill ist
das **Profil** dazu: er füllt die Hooks des Cores mit den EDP-Fakten. Nichts aus dem Core hier wiederholen.

## Profil

### `«HOST»` — GHE-Instanz

- `gh -R einsatzleitsoftware.ghe.com/edp/<repo>`. Aufruf-Quirks der Instanz:
  `$VAULT/referenz/ghe-instance-quirks.md`.
- Issue-Referenz aus `$ARGUMENTS`: URL-Muster `.../edp/<repo>/issues/<nr>` oder blanke Nummer + aktuelles Repo.

### `«STATUS-SIGNAL»` — `status:active`

Sobald Repo + Issue-Nummer feststehen und die Bearbeitung beginnt, `status:active` setzen und **jedes andere
`status:*`-Label entfernen** (aktuell nur `status:paused`), damit das Team live sieht, dass das Issue in
Umsetzung ist:

```bash
gh issue edit <nr> -R einsatzleitsoftware.ghe.com/edp/<repo> --add-label "status:active" --remove-label "status:paused"
```

(`--remove-label` für ein nicht gesetztes Label ist ein No-op — unkritisch.) Read-back nicht nötig, aber bei
Fehler transparent melden ([[tim/feedback/schreib-verify]]).

### `«TICKET»` — Zammad

- **Jede erwähnte Zammad-Nummer** (`EDP#<nr>`) via `/zammad-read` auflösen — inkl. Kunden-Artikel,
  Screenshots und exakter Trigger-Beschreibung.
- **GHE-Bildanhänge sind SSO-gated:** `/user-attachments/assets/...` liefert per `curl`/Token die Login-HTML
  statt des Bildes (kein API-Token-Zugriff). Screenshot-Inhalt nicht so beschaffen wollen — stattdessen den
  gemeldeten Ist-Zustand in der Dev-Umgebung reproduzieren und dort visuell erfassen.

### `«CHECKOUT»` — EDP-Projektwurzel

Repo-Checkout gemäß `$VAULT/referenz/edp-project-root-mac.md`.

### `«BRANCH»` — Branch-Cascade Fall A–D

> 🔴 **Vorrangig, vor jeder Cascade-Überlegung: Arbeit in EDP-Repos landet auf `dev`.**
> Promotion nach `beta`/`release` ist eine Release-Entscheidung des Teams, kein Bestandteil eines
> Fixes — und **kein selbst eröffneter Kaskaden-PR**. Ein bestehender Kaskaden-PR darf abgearbeitet
> werden; eine Auslieferung wird nicht angestossen.
> Volltext: [[tim/feedback/edp-nur-dev-promotion-ist-teamsache]].
>
> Das gilt **auch dann**, wenn die Fall-A–D-Prüfung unten formal auf `release` oder `beta` zeigt, und
> **auch dann**, wenn der Issue-Body eine fertige `## Branch & Cascade`-Sektion mit genau dieser Vorgabe
> trägt. Gemessen 2026-08-21 (`edp/datenbank#33`): beides zusammen ergab einen sehr überzeugenden
> falschen Pfad — der PR ging gegen `release`, musste zurückgezogen und gegen `dev` neu aufgesetzt
> werden (#54 → #55). Erschwerend: die Begründung im Issue („sonst bleiben die Reste auf `beta`/`release`
> liegen") war zum Bearbeitungszeitpunkt **überholt**; eine Vorgabe im Issue-Text ist eine Messung von
> damals, nicht von heute.
>
> Prüffrage vor der Branch-Wahl: *ändert dieser Vorgang, was ein ausgeliefertes Programm tut?* Bei
> `.gitignore`, CI-Konfiguration, Deskriptor oder Doku ist die Antwort nein — dann gibt es erst recht
> keinen Grund, einen Auslieferungsweg zu öffnen.
>
> Die Fall-A–D-Bestimmung darunter bleibt nützlich, aber für eine **andere** Frage: sie sagt, wo der
> Defekt sitzt und was im Bericht zu erwähnen ist — nicht, wohin der PR geht.

Den **niedrigsten betroffenen Branch** (Fall A–D) und den Cascade-Pfad bestimmen — verbindlich aus der
repo-eigenen `docs/GIT.md`. **Nicht jedes Repo hat sie** (`edp/einsatzmonitor` führt gar kein `docs/`);
dann ist der Kopfkommentar von `.github/workflows/auto-cascade.yml` die Quelle im Repo — er benennt die
Richtung ausdrücklich. Ergänzt durch `$VAULT/referenz/edp-schnittstellen-branch-konvention.md`,
`$VAULT/projekte/edpweb/architektur.md` (Branching) und [[tim/feedback/issue-fix-branch-cascade-festhalten]].
Fix-Branch von der korrekten Basis anlegen (nie auf den Default-Branch direkt committen).

Beim Erfassen (Core-Schritt 1) eine im Issue-Body bereits vorhandene Sektion **`## Branch & Cascade`**
mitlesen — sie ist die Vorgabe des Melders und wird gegen die eigene Cascade-Prüfung abgeglichen, nicht
blind übernommen.

> 🔴 **Den Default-Branch messen, bevor irgendetwas darauf aufbaut** — ein Einzeiler, der eine falsche
> `## Branch & Cascade`-Angabe sofort aufdeckt:
>
> ```bash
> gh api "repos/edp/<repo>" --hostname einsatzleitsoftware.ghe.com -q .default_branch
> ```
>
> Gemessen 2026-08-21: `installer#92` nannte „das Repo führt nur `main`" — der Default ist `dev`, `main`
> gibt es nicht. Dieselbe Falschangabe stand in `edp-runtime-redist#5`; beide Repos sind am 2026-08-19
> umbenannt worden, ältere Issues tragen den alten Namen weiter. Ein `git checkout main` scheitert dann
> mit einer Meldung, die nach kaputtem Klon aussieht. Die Korrektur gehört **in den Issue-Body**, nicht
> nur in einen Kommentar — sonst trägt der Nächste sie weiter.

> ⚠️ **Ein Branch-Hinweis im Issue-Titel/-Text (z.B. `[... (dev)]`) ist nur der Melde-Kontext, NICHT
> zwangsläufig der niedrigste betroffene Branch.** Immer aktiv per `docs/GIT.md` + Cross-Branch-Prüfung
> verifizieren, auf welchem Branch der Bug **tatsächlich zuerst** auftritt (er kann tiefer liegen als
> gemeldet, oder sich seit Ticket-Erstellung verschoben haben). Bei Bugs heißt das: prüfen, ob das
> fehlerhafte Verhalten auch auf `release`/`beta` reproduzierbar ist bzw. ob das betroffene Feature dort
> überhaupt existiert — erst dann steht der Fix-Branch fest.
>
> 🔴 **Auch die Cascade-RICHTUNG in einer vorhandenen `## Branch & Cascade`-Sektion gegenprüfen, nicht nur
> die Ebene.** Gemessen 2026-08-21 (`edp/einsatzmonitor#15`): dort stand „Fix-Branch von `dev`, danach die
> übliche Kaskade `dev` → `beta` → `release`" — genau verkehrt herum. `auto-cascade.yml` zieht nach **oben**
> (`release` → `beta` → `dev`, dev = Endstation); `dev` → `beta` → `release` ist die **Promotion** (Fall D),
> keine Kaskade. Wer das übernimmt, kündigt Cascade-PRs an, die nie entstehen. Und eine Aussage über die
> vorhandenen Kanäle **altert**: dasselbe Repo hatte laut `#12` „nur den Kanal `dev`", führte aber inzwischen
> `beta` und `release`. Also `git branch -r` selbst fahren, statt eine ältere Messung im Issue zu glauben.

> **Manche Issues erfordern Änderungen in mehreren Repos** (z.B. Verbraucher/Consumer eines geteilten
> Mechanismus umbauen, **bevor** die eigentliche edpweb-Änderung sicher ist — Beispiel: Redist-Bundle
> #452, wo CI-Runner + edp-ctrl vor der DLL-Entfernung provisionieren mussten). Dann **pro Repo** einen
> eigenen Branch + PR und die **Merge-Reihenfolge** explizit bestimmen und im Report festhalten: ein
> edpweb-PR, dessen CI eine geteilte Action/Engine auf `@main`/`@dev` auscheckt (z.B. `delphi-devsetup`),
> wird erst grün, wenn die Vorbedingungs-PRs dort gemergt sind — bis dahin ist seine rote CI
> erwartungsgemäß (transparent dokumentieren, nicht als eigenen Fehler fehldeuten). Verifikation je Repo
> mit dem passenden Mittel: nicht-edpweb-Consumer sind ggf. nicht via `/edp-develop` deploybar (z.B. eine
> PowerShell-CI-Engine) → dort die Engine-Tests/den echten Stand auf der Dev-VM fahren bzw. den realen
> CI-Lauf nach dem Merge abwarten.

### `«ENCODING»` — Win-1252 bei Delphi

Datei-Encoding strikt beachten ([[tim/feedback/datei-encoding]], `$VAULT/referenz/edp-cascade-encoding-check.md`)
— v.a. Windows-1252 bei `.pas`/`.dpr`/`.dpk`/`.inc`/`.dfm`, UTF-8 bei Frontend/sonstigen. Echte Umlaute.

### `«TESTS»` — DUnitX / go test / Repo-Standard

Delphi = DUnitX (`$VAULT/referenz/dunitx-patterns.md`,
`$VAULT/projekte/edpweb/dunitx-test-harness-pickup.md`), Go = `go test`, Frontend = Repo-Standard
([[tim/feedback/delphi-tests-immer]]). Build/Deploy **nur** via `/edp-develop`.

> **Ein grüner Test, der nicht rot werden kann, belegt nichts.** Jede neue Schutzmaßnahme einmal
> **mutationsprüfen**: die Logik gezielt kaputtmachen, Suite laufen lassen, Rot sehen, zurückbauen. Und
> die Probe auf die **Verdrahtung** nicht vergessen — deckt der Test nur die Funktion, bleibt die Suite
> grün, wenn jemand ihren Aufruf löscht oder verschiebt. Genau diese Lücke ist der Regelfall bei
> Konfigurations-/Engine-Bugs: sie sind meist ein fehlendes Stück Verdrahtung, kein falscher Algorithmus.
> Die Mutations-Ergebnisse gehören als Tabelle in den PR-Body — sie sind der Beleg, den ein Reviewer
> sonst selbst herstellen müsste.

> ⚠️ **Ein Test kann den falschen Text lesen und ist dann grün, ohne etwas zu messen.** Nicht nur „greift
> die Prüfung?", sondern „greift sie auf den **Prüfgegenstand**?". Gemessen 2026-08-21 (installer#132): eine
> Zusicherung suchte `GPLv2` in der `[Code]`-Sektion einer `.iss`. Der Helfer filtert nur `;`-Kommentare —
> die Schreibweise **ausserhalb** von `[Code]`; im Pascal-Script kommentiert man mit `//`. Der erklärende
> Kommentar über der Prozedur nannte selbst „GPLv2", der Test las also ihn statt den Code und blieb grün,
> als der Hinweistext ausgedünnt wurde. Auffällig wurde es erst durch die Mutationsprobe. Also: die Mutation
> so wählen, dass sie **nur den Gegenstand** trifft, nicht dessen Beschreibung — und wenn die Suite dabei
> grün bleibt, ist der Test schuld, nicht die Mutation.

> ⚠️ **Zum Zurückbauen einer Mutation NIE `git checkout -- <datei>`.** Das stellt aus dem **Index** her und
> verwirft dabei stillschweigend jede noch nicht committete Änderung in derselben Datei — in diesem Lauf
> ist so eine frisch geschriebene Funktion verschwunden. Stattdessen **vor** der Mutationsreihe committen
> oder die Datei nach `$CLAUDE_JOB_DIR/tmp` kopieren und von dort zurückspielen.

### `«VERIFY»` — ausschließlich Dev-VM

> **Zwingend: Test/Verify NUR in der Dev-Umgebung.** Jede Verifikation läuft gegen den **frisch auf die
> Dev-VM deployten** Stand — Delphi/Frontend via `/edp-develop` (`edp-ctrl dev compile <projekt>` baut
> das **ganze** Frontend — der Ausgabekopf sagt `Frontend kompilieren (npm run build)`, das zieht
> `scss:build` **und** `module:build` mit; ein separates `module:build` auf der VM ist überflüssig,
> zweimal unabhängig gemessen 2026-08-19), UI via `/edp-design-loop`, Backend via
> HTTP-POST/DB-Read-Back **gegen die VM**. Ein lokales
> Render-Harness, ein lokaler Build oder „CI ist grün" sind **KEIN Ersatz** — nur auf der Dev-VM herrschen
> reale Bedingungen, und nur so kann Tim die Änderung **selbst** live ansehen. Also **immer erst deployen,
> dann verifizieren**. Geht der Deploy nicht (VM down, Compile hängt) → transparent melden, nicht mit einer
> lokalen Ersatz-Verifikation kaschieren.

**Die Dev-VM ist exklusiv zu belegen** — `compile`, `test` und `service start|stop` erst nach gesetztem
`C:\vm.lock`, sonst misst eine parallele Session still gegen fremden Code ([[tim/feedback/dev-vm-exklusiv-belegen]]).

> 🔴 **Dev-VM ≠ Build-VM — nicht verwechseln, und die zweite ist autonom NICHT erreichbar.** Die
> **Dev-VM** (`edp-ctrl config get vm-host`, auf Poseidon `eifert-dev`) ist das Ziel aller Deploys oben.
> Die **CI-Build-VM** `edpttz-svghr01` = `10.36.10.6` ist eine andere Maschine (Zugang `ssh edpci@…`,
> [[referenz/delphi-ci-service-account]]) und hängt hinter dem **edp-OpenVPN mit YubiKey-PIN** — ein
> interaktiver Schritt, den ein autonomer Lauf nicht ausführen kann. Ein Issue, dessen Gegenstand die
> **Bau-Engine** ist (`delphi-devsetup`, Runner-Provisionierung, Library-Suchpfade), lässt sich also
> weder per `/edp-develop` deployen noch auf der Build-VM nachmessen. **Nicht daran hängenbleiben** und
> auch nicht als Blocker melden — stattdessen:
>
> 1. Die Behauptung **offline hart belegen**, statt sie zu vermuten: `.dproj`-Ausgabepfade
>    (`DCC_DcuOutput` **pro PropertyGroup** lesen — ein Override kann nur für eine Config/Plattform
>    gelten), die Pins aus `<konsument>/ci/dependencies.psd1` und die GitHub-Trees-API
>    (`?recursive=1`) gegen den gepinnten SHA. Methode im Volltext:
>    `$VAULT/projekte/delphi-ci-runner/dependency-strategie.md` § „Library-Suchpfad offline auditieren".
> 2. Die **Engine-Tests** des Repos lokal fahren (dort Plain-PowerShell-Skripte, **kein** Pester) und
>    zusätzlich **gegen die Baseline** (`origin/<base>`), damit ein roter Test nicht als
>    „gab es vorher schon" durchrutscht.
> 3. Im PR-Body **ausdrücklich benennen**, was dieser PR nicht prüfen kann und welcher spätere Lauf den
>    Rest belegt — transparent statt kaschiert. `todo:testing` setzen.
Der Lock schützt das **EDP-Projektverzeichnis**, das `edp-ctrl dev compile` per `reset --hard` umsetzt. Eine
Verifikation, die dieses Verzeichnis gar nicht anfasst (eigener Checkout, z.B. ein Installer-Probebau), braucht
ihn **nicht** — dann auf einen fremd gehaltenen Lock **nicht warten**, aber ihn auch nicht überschreiben.

> **Nennt das Akzeptanzkriterium ein Kommando, dieses vor dem Ausführen gegen das Skript prüfen.** Gemessen
> 2026-08-21: `#15` verlangte `Build-Installer.ps1 -Produkt monitor -Kanal dev`, der Parameter heisst aber
> `-Channel` — so notiert läuft der geforderte Nachweis nicht. Die Abweichung gehört als Kommentar ans Issue,
> damit der Nächste nicht dasselbe sucht.

**Repro-/Test-Wissen zuerst nutzen, nicht neu erfinden:**
- Backend deterministisch per HTTP-Form-POST: `$VAULT/referenz/edpweb-testing/index.md` (Hub → `setup`, `auth`,
  `snippets`, `actions-<bereich>`, `db-kerntabellen`).
- UI-Reproduktion/Verifikation: `/edp-design-loop` bzw. direkt `/playwright-cli` (Login/Cache-Fallen:
  [[tim/feedback/code-self-check-vor-review]]).
- DB-Read-Back: `/edp-database` + `$VAULT/referenz/edpweb-testing/db-kerntabellen.md`.
- Reproduktion auf Release-/Kundenstand zur Abgrenzung: `$VAULT/referenz/edpweb-demo-instanzen.md`;
  Testdaten/Lage: `$VAULT/referenz/edpweb-demo-lage-reset.md`.
- Repo-spezifische Notes unter `$VAULT/projekte/<repo>/` und `$VAULT/referenz/` (z.B. `delphi-live-debug-vm.md`).

> **Dev-VM-Verifikation — drei wiederkehrende Vorbedingungen:**
> 1. **Feature-Branch vorher auf `origin` pushen** (alle Repos) — der Git-Sync von `edp-ctrl dev compile`/
>    `test` vergleicht `HEAD..origin/<branch>`; ein nie gepushter Branch bricht mit „unbekannter Commit …
>    origin/<branch>" ab (nicht als VM-/Compile-Fehler fehldeuten).
> 2. **edpweb-DUnitX-Suite mit `--platform Win64` fahren, nach einem vorherigen `compile`** — das
>    Test-`.dproj` ist Win64-orientiert und reused die `..\Win64\Release`-DCUs des Haupt-Builds (inkl.
>    CCR.Exif). Der `edp-ctrl dev test`-Default Win32 scheitert sonst mit `F2048`/`F2613`, was **nichts**
>    mit dem Fix zu tun hat. Details: [[projekte/edpweb/dunitx-test-harness-pickup]].
> 3. 🔴 **Nach der Lock-Freigabe KEINE Messung mehr gegen die VM — auch keine lesende.** Sobald der Lock
>    weg ist, deployt eine andere Session sofort ihren Branch. Eine Messung danach misst fremden Code, und
>    das Fehlerbild zeigt auf den **eigenen**: Gemessen 2026-08-19 (#413) kam nach der Freigabe ein
>    `EINSATZNUMMER = NULL` zurück, wo eben noch der Wert stand, plus ein 500 auf dem eigenen
>    JSON-Endpunkt — beides sah nach Regression im eigenen Fix aus und war ein anderer Stand
>    (`git log -1` im VM-Projektverzeichnis zeigte einen fremden Branch). Also **alle** Messungen innerhalb
>    der eigenen Lock-Zeit abschliessen; muss später nachgemessen werden, erst den Lock wieder holen und den
>    deployten Branch gegenlesen. Reine CSS-/Farbfragen brauchen die VM ohnehin nicht — dafür
>    `$VAULT/referenz/edpweb-testing/frontend-ui-harness.md`.

> **Nennt das Akzeptanzkriterium einen Bau in einem ANDEREN Repo, läuft die Verifikation dort** — nicht
> via `/edp-develop`. Typisch bei Aufräum-Issues, deren Nachweis „das Setup baut ohne diese Datei" lautet:
> dann `edp/installer` auf der Dev-VM auschecken und `scripts\Build-Installer.ps1` fahren. Werkzeugbeschaffung,
> Anmeldung und die Fallen (Inno Setup kommt inzwischen von den `jrsoftware/issrc`-GitHub-Releases, `gh` fehlt
> auf der VM, verschachteltes SSH-Quoting schluckt die Ausgabe) stehen in
> `$VAULT/projekte/installer/probelauf-dev-vm.md`. 🔑 Der **stärkere** Beleg als der grüne Lauf ist dort die
> `components.lock.json`: sie zeigt, dass der Bau nur Release-Assets zieht und das Komponenten-Repo nie
> auscheckt — „liest der Bau Datei X noch?" ist damit strukturell beantwortet, nicht nur stichprobenhaft.

> **Ausnahme — das Issue liegt in einem Repo, das gar keinen Dev-VM-Deploy kennt** (z.B. `edp/installer`,
> `edp/edp-runtime-redist`, `edp/.github`): Dort ist die Dev-VM nicht die reale Umgebung, sondern der
> **CI-Runner**, und der läuft am PR ohnehin. Nicht künstlich auf die VM ausweichen — verifiziert wird:
>
> 1. **Suite lokal** — `pwsh` liegt auf Poseidon, Pester ≥ 5 ist da. `Invoke-Pester` gegen `tests/` gibt in
>    Sekunden die Baseline **vor** der Änderung; ohne sie ist „meine Änderung hat nichts kaputtgemacht"
>    unbelegt.
> 2. **Der PR-Lauf auf `windows-latest`** — bei `edp/installer` der Job `Trockenbau <produkt>`. Der zieht die
>    echten `dev-latest`-Assets, verifiziert das Redist-Bundle gegen SHA256 und ruft ISCC. Das **ist** der
>    reale Bau, kein Ersatz dafür.
> 3. **Das PR-Artefakt gegenlesen**, nicht nur den grünen Haken: `components.lock.json` zeigt je Asset Tag,
>    Commit und beide Prüfsummen (`sha256_original` ≠ `sha256_verbaut` genau dann, wenn gestempelt wurde).
>    Verlangt ein Akzeptanzkriterium „am Artefakt geprüft, nicht an der `.iss`", ist der stärkste erreichbare
>    Beleg die **ISCC-Ausgabe im CI-Log** (`Compressing: …\_stage\<produkt>\<datei>`) — sie zeigt die
>    tatsächlichen Quellpfade des Baus. 🔴 In die fertige `setup.exe` hineinzusehen geht auf Linux **nicht**:
>    `innoextract` 1.9 (Arch) kann nur bis Inno 6.0.5, gepinnt ist 6.7.1, und `7z` kennt das Format nicht.
>    Diese Grenze **benennen** statt sie mit einer schwächeren Prüfung zu kaschieren.

> **Ausnahme — die Änderung IST eine CI-/Delivery-Workflow-Datei** (z.B. `.github/workflows/delivery.yml`
> selbst): Die lässt sich nicht via `/edp-develop` auf die Dev-VM deployen. Verifikation dann **artefakt-basiert**:
> `branch-build.yml` baut bei jedem Feature-Push die `.exe` als Workflow-Artefakt (kein Release); für den
> Installer-/Delivery-Pfad die `delivery-assets`-**Workflow-Artefakte** inspizieren, danach den echten Lauf
> nach Merge abwarten. ⚠️ **NIEMALS naiv `gh workflow run delivery.yml --ref <feature-branch>` als „harmlosen
> Testlauf" annehmen:** der `publish`-Job legt via `delphi-release`-Action ein rollendes `<branch>-latest`-
> **Waisen-Release** an (nur der Installer-Job ist test-gated) — das bleibt nach Merge/Branch-Delete zurück und
> muss manuell weg. Wenn ein Dispatch nötig war: **immer** `gh release list -R einsatzleitsoftware.ghe.com/edp/<repo>`
> prüfen + jede `<branch>-latest`-Leiche mit `gh release delete <tag> --cleanup-tag --yes` entfernen. Volltext:
> [[tim/feedback/keine-workflow-dispatch-waisen-releases]], `$VAULT/referenz/edpweb-delivery-pipeline.md`.
> (Ein PR triggert `delivery.yml` **nicht**.)

**Zusätzlich bei Cascade-Bug (Fall C):** prüfen, ob der Fix in **beiden** betroffenen Codebasen greift, falls
das Repo pro Branch getrennte Renderer/Module hat (siehe `$VAULT/projekte/edpweb/architektur.md`).

### `«WISSEN»` — Vault-SSoT + Issue

Endpunkt-/Repro-Wissen → `$VAULT/referenz/edpweb-testing/` (Hub-Konvention); Architektur/Repro-Ablauf →
`$VAULT/projekte/<repo>/`. Niemals dupliziert, konsistent mit vorhandenem Frontmatter-/Verifiziert-Marker-Stil.
Fehlt am Issue die Sektion **`## Branch & Cascade`** (Fix-Branch + Cascade-Pfad + Test-Akzeptanzkriterium),
diese ergänzen, damit Bearbeiter sie direkt anwenden können ([[tim/feedback/issue-fix-branch-cascade-festhalten]]).
Schreibaktionen auf GHE via `gh` (Host-Quirks: `$VAULT/referenz/ghe-instance-quirks.md`).

**Randfunde** — was am Rande auffällt, aber eine eigene Entscheidung oder Bauprobe braucht, wird
ausgekoppelt statt mitgefixt: eigenes Issue mit Messung + `## Branch & Cascade`, Assignee `tim-rudorf`
([[tim/feedback/randfunde-als-issue]]). ⚠️ **Erst das Issue anlegen, dann seine Nummer im Code/PR
referenzieren** — die nächste freie Nummer lässt sich nicht vorhersagen (Issues und PRs teilen sie sich;
in diesem Lauf war die geratene bereits vergeben und musste per Folge-Commit korrigiert werden).

> 🔴 **Vor jedem `gh issue create` den Bestand prüfen — offen UND geschlossen, Titel UND Body**
> ([[tim/feedback/issue-bestand-pruefen-vor-neuanlage]]). Gemessen 2026-08-21 (`edp/datenbank#33`): von 14
> org-weiten Randfunden waren **12 bereits erfasst**, blind angelegt wären das 12 Dubletten gewesen. Zwei
> Fallen dabei:
> - **Titel-Abgleich reicht nicht.** `schn_webhook#13` heißt „Auto generate ssl zertifikat" und behandelt
>   im Body die gesuchte `ssl.key` vollständig. Ein Vorgang kann den Fund auch in einem **anderen** Repo
>   mitnennen (`schn_alamos#13` nennt `schn_webhook` mit).
> - **Geschlossen ≠ behoben.** Fünf Vorgänge standen als `completed` geschlossen, während die Dateien
>   unverändert im Baum lagen. Das ist ein eigener Befund und wird **berichtet**, nicht eigenmächtig
>   durch Wiedereröffnen korrigiert — ein geschlossener Vorgang kann eine bewusste Entscheidung sein.

⚠️ **Secrets sind von „Randfund mitfixen" ausgenommen:** erfassen als Issue, sonst nichts — keine Löschung,
kein `.gitignore`-Eintrag, keine Rotation, kein PR ([[tim/feedback/edp-secrets-nur-als-issue]]).

### `«PR»` — `/edp-pull-request` + Label-Schema

**PR** via `/edp-pull-request` (Titel/Body/Zammad-Notiz/Assignee `tim-rudorf` per dessen Konvention).

**PR-Label automatisch setzen** (nach dem Erstellen, per
`gh pr edit <nr> -R einsatzleitsoftware.ghe.com/edp/<repo> --add-label "..."`):

- **Ein `merge:*`-Label** — nach eigener Einschätzung der Art der Änderung (bestimmt die Release-Notes-Kategorie):
  - `merge:bug` — Fehler in einer bereits implementierten Funktion behoben (der Standard-Fall).
  - `merge:feature` — Erweiterung/Anpassung einer bereits existierenden Funktion.
  - `merge:core-feature` — komplett neue, große/relevante Funktion oder große Überarbeitung.
  - `merge:design/usability` — reine Bedienbarkeits-/UI-Überarbeitung ohne neue Funktion.
  - `merge:refactoring` — Code-Umbau ohne Funktionsänderung.
  - `merge:tests` — ausschließlich neue automatisierte Tests für vorhandene Funktion.
  - `merge:documentation` — nur Doku (Feature-/Projekt-/Code-Doku).

  Genau **ein** passendes wählen (im Zweifel das dominante Änderungsmotiv des PRs). Bewusst reine Release-Notes-
  Flags (`merge:no-release-note`, `merge:release-note-etc`) nur setzen, wenn das erkennbar gewollt ist.

- **`todo:*`-Label** — was nach dem Merge-Ready-Zustand noch an **menschlicher** Arbeit offen ist:
  - `todo:review` — praktisch immer setzen (Code/Konzept braucht menschliches Review über das lokale hinaus).
  - `todo:testing` — zusätzlich setzen, wenn die Änderung sinnvoll noch einen **manuellen** Funktionstest durch
    einen Menschen braucht (typisch bei UI-/Workflow-Änderungen; bei reinem Refactoring/Doku i.d.R. nicht nötig).

**Copilot wird nicht mehr angefordert** — der Bot ist auf der Instanz inaktiv, `--add-reviewer` ist ein stiller
No-op ([[tim/feedback/pr-review-lokaler-agent]]).

### `«ABSCHLUSS»` — merge-ready, Merge macht das Team

Definition of Done ist der **mergebare** Zustand ([[tim/feedback/pr-fertig-erst-wenn-mergebar]]). Den
eigentlichen Merge dem Team/Reviewer überlassen — **nicht selbst mergen**.

### `«TABUS»`

- **Testen/Verifizieren/Reproduzieren IMMER nur in der Dev-Umgebung** (siehe `«VERIFY»`). Lokales
  Render-Harness / lokaler Build / CI-grün sind KEIN Ersatz ([[tim/feedback/code-self-check-vor-review]]).
- **Kein `gh workflow run` auf `delivery.yml`** ohne die Waisen-Release-Nachkontrolle (siehe `«VERIFY»`).
- **Externer Kundenversand** (Zammad public) nur mit Freigabe und in Tims Duktus (CLAUDE.md).
- **Keine Jarvis-/Vault-Verweise** in Issue-, PR-, Commit- oder Zammad-Text — der Sachgrund gehört inline
  ([[tim/feedback/keine-jarvis-referenzen-extern]]).
- **Git-Author** ist `Tim Rudorf <tim.rudorf@einsatzleitsoftware.de>` aus der Repo-Config; nie
  `-c user.name`/`-c user.email` am Commit ([[tim/feedback/git-author-arbeit-repos]]).

## Zusatz zu Core-Schritt 1 (Erfassen)

> 🔴 **Den Ist-Wert des Issues nachmessen, bevor irgendetwas umgesetzt wird.** Ein Issue-Body ist eine
> Messung von seinem Erstellungstag, kein aktueller Zustand — und zwischen Erstellung und Bearbeitung
> liegen oft Wochen und fremde Merges. Also jede im Issue behauptete Fundstelle einmal gegen den heutigen
> Stand prüfen (`git ls-tree -r --name-only origin/<branch>`, `git log --diff-filter=D -- <pfad>`,
> `git show "origin/<branch>:<pfad>"` — Anführungszeichen zwingend, zsh frisst sonst `:c`/`:s` hinter der
> Variablen, siehe `$VAULT/referenz/stille-messfallen-shell-git.md`).
>
> Gemessen 2026-08-21 (`edp/datenbank#33`): **drei der vier Akzeptanzkriterien waren bereits erfüllt** —
> die zu entfernenden Dateien lagen seit einer Stunde nach Issue-Erstellung auf keinem Kanal mehr, und die
> im Issue offengelassene Entscheidung war faktisch schon gefallen. Wer den Body als Auftrag abarbeitet,
> baut hier Änderungen, die es nicht mehr braucht, und übersieht den einen wirklich offenen Punkt.
>
> Ergebnis der Nachmessung gehört als Kommentar ans Issue (Kriterium für Kriterium: erledigt / offen, je
> mit Beleg) — das ist zugleich das Gerüst für den späteren PR-Body.

## Zusatz zu Core-Schritt 8b (CI beobachten)

> ⚠️ **`gh pr checks` liefert direkt nach einem Push eine unvollständige Liste.** Eine Abbruchbedingung
> „alle Checks sind nicht mehr `pending`" ist dann **trivial erfüllt** und meldet grün, während der Lauf
> gerade erst anläuft. In diesem Lauf hat genau das einmal ein falsches „alle Checks abgeschlossen" mit
> einem einzigen Check erzeugt.
>
> Belastbar ist erst: **`ci-summary` ist in der Liste vorhanden UND nicht mehr `pending`**, zusätzlich die
> Gesamtzahl der Checks gegenlesen (in `edp/datenbank` sind es 14). `ci-summary` ist ohnehin der einzige
> Pflicht-Kontext der Organisation — was ihn nicht enthält, ist keine Aussage über den Lauf.

### Der Format-Bot pusht in deinen Branch

Die zentrale Format-Stufe (`format / prettier`) **schreibt zurück und committet in den Feature-Branch**.
Der nächste eigene Push wird dann als non-fast-forward abgelehnt — das ist kein Fehler, sondern der
Normalfall, sobald der PR Markdown oder YAML berührt hat.

- **Vorbeugen:** vor dem Push mit der org-gepinnten Fassung selbst formatieren. Version und
  `prettierrc.json` liegen zentral in `edp/.github` unter `actions/format-prettier/` — von dort holen
  statt raten. Dann bleibt der Branch, wie man ihn gepusht hat.
- **Wenn es doch passiert:** `git fetch` + `git rebase origin/<branch>`, **nicht** force-pushen. Bei einem
  Konflikt in einer formatierten Datei nicht von Hand mergen — die eigene (inhaltlich korrigierte) Fassung
  nehmen und **prettier erneut darüberlaufen lassen**; sonst kämpft man gegen den Formatierer.
- Danach die Suite erneut fahren: der Rebase kann Änderungen aus zwei Commits zusammenführen, die einzeln
  grün waren.

## Zusatz zu Core-Schritt 4 (Feature)

> **Berührt das Issue eine Oberfläche, ist `edp-frontend-design` verbindlich** — auch bei einem
> reinen „Feld ergänzen". Er hält den EDP-Kanon (Fluent 2 als Vorbild, Primary abgeschafft zugunsten
> von Secondary, keine Versalien/Sperrung, Weißraum statt Linien) und verweist auf die belegten
> Fluent-2-Werte in `$VAULT/referenz/fluent2-design.md`. Nicht den generischen
> `frontend-design:frontend-design` direkt nutzen — `edp-frontend-design` zieht ihn selbst als Basis heran.

## Zusatz zu Core-Schritt 7/8: fremde Repos — erst lesen, dann schreiben

Berührt das Issue ein **anderes** Repo (Blocker, Zulieferer, Bundle), vor jedem Kommentar oder Issue dort
den **aktuellen Stand** erheben — `gh pr list --state open` **und** `gh issue list`, nicht nur das eine
verlinkte Issue. Sonst schreibt man eine Analyse zu einer Frage, die dort längst entschieden ist.

Gemessen 2026-08-21: Ein ausführlicher Kommentar an `edp-runtime-redist#5` legte eine Designfrage dar
(Namensschema für zwei Architekturen), die der offene PR #21 desselben Repos bereits anders entschieden
hatte — nur x64, schlichter Dateiname. Der Kommentar brauchte einen Nachtrag, der ihn zu zwei Dritteln
zurücknahm. Ein `gh pr list` vorher hätte das gespart.

Ebenso: **fremde PRs nicht anfassen und nicht auf sie warten**
([[tim/feedback/fremde-prs-sind-kein-blocker]]) — aber prüfen, ob sich der eigene Vorgang durch sie
**erledigt** hat. Läuft parallel eine Session am selben Strang, kurz abstimmen, wer welches Repo hält;
das verhindert doppelte Arbeit an derselben Datei.

> **Löst sich ein Blocker mitten im Lauf auf, den Stand selbst nachmessen** statt der Meldung zu glauben:
> Release da? Asset drin? Und vor allem — **der Freigabe-Pin gezogen?** Bei `edp/edp-runtime-redist` ist
> `pins/redist-bundle.txt` der Schalter, der ausrollt; `release.yml` fasst ihn **nicht** an. Ein Release
> ohne nachgezogenen Pin ist für jeden Konsumenten folgenlos. Rezept:
> `$VAULT/referenz/edp-redist-komponente-pruefen.md`.

Abschließend `skill-optimize` mit `edp-issue` aufrufen.

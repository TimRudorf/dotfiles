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

> 🔴 **Arbeitsverzeichnis so anlegen, dass `edp-ctrl` es findet — sonst misst später der falsche
> Stand.** `edp-ctrl dev compile|test <projekt>` sucht **`<project-root>/<projekt>`** und leitet den
> Branch aus dem dortigen Klon ab. Ein `git worktree` unter `.worktrees/<vorgang>` heisst nicht
> `<projekt>` und wird deshalb **nicht** gefunden; ohne `--project-root` greift der Vorgabewert
> `~/dev/EDP` und damit der Haupt-Klon auf `dev` — der Lauf ist dann grün und hat den eigenen Fix
> nie gesehen.
>
> Richtig ist eine Ebene mehr:
>
> ```bash
> git worktree add ~/dev/EDP/.worktrees/<vorgang>/<repo> -b <branch> origin/dev
> edp-ctrl dev test <repo> --project-root ~/dev/EDP/.worktrees/<vorgang>
> ```
>
> Gemessen 2026-08-21 (`einsatzmonitor#10`): flach als `.worktrees/em-i10` angelegt, danach per
> `git worktree move` umgezogen. Direkt richtig anlegen spart den Umzug.
>
> Der Ausgabekopf jedes `compile`/`test` nennt Branch **und** Commit — den einmal gegenlesen,
> bevor ein Ergebnis als Beleg verwendet wird.

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

### `«ENCODING»` — pro Repo messen, Win-1252 ist nur der Regelfall

Datei-Encoding strikt beachten ([[tim/feedback/datei-encoding]], `$VAULT/referenz/edp-cascade-encoding-check.md`)
— **im Regelfall** Windows-1252 bei `.pas`/`.dpr`/`.dpk`/`.inc`/`.dfm`, UTF-8 bei Frontend/sonstigen. Echte Umlaute.

> 🔴 **„Delphi = Win-1252" ist eine Annahme, keine Messung — einzelne Repos haben umgestellt.**
> `edp/schn_ivena` führt seine Delphi-Quellen seit `d3453bf` repo-weit als **UTF-8 mit BOM**; die CI-Stufe
> `delphi / encoding` erzwingt dort genau das. Wer die Hausregel blind anwendet und die Datei per
> `iconv -f WINDOWS-1252 -t UTF-8` dreht, kodiert doppelt — Symptom sind `â€"`/`Ã¼` statt `—`/`ü`, und
> beim Zurückschreiben ist die Datei kaputt. Gemessen 2026-08-21 (`schn_ivena#83`): genau dieser
> iconv-Aufruf lieferte Mojibake, obwohl die Quelldatei in Ordnung war.
>
> Also **vor dem ersten Edit messen**, nicht annehmen:
>
> ```bash
> file -b <datei>                        # "UTF-8 (with BOM)" vs. "ISO-8859"/"Non-ISO extended-ASCII"
> git log --oneline -- <datei> | head    # eine Encoding-Umstellung steht als eigener Commit drin
> ```
>
> In UTF-8-mit-BOM-Repos ist der BOM Teil des Vertrags: beim byte-genauen Patchen mit `utf-8-sig`
> dekodieren, mit vorangestelltem `\xef\xbb\xbf` zurückschreiben und danach auf U+FFFD prüfen.

### `«TESTS»` — DUnitX / go test / Repo-Standard

Delphi = DUnitX (`$VAULT/referenz/dunitx-patterns.md`,
`$VAULT/projekte/edpweb/dunitx-test-harness-pickup.md`), Go = `go test`, Frontend = Repo-Standard
([[tim/feedback/delphi-tests-immer]]). Build/Deploy **nur** via `/edp-develop`.

> **Rot vor Grün, ohne gegen „nur grün committen" zu verstossen: zwei Commits.** Der Core verlangt bei
> Bugs erst den reproduzierenden Test (rot), [[tim/feedback/delphi-tests-immer]] verlangt, nur grün zu
> committen. Beides zusammen geht als **Commit 1 = Tests** (an dieser Stelle rot, im Commit-Text
> ausdrücklich als solcher benannt), **Commit 2 = Fix** (ab hier grün). `edp-ctrl dev test` fährt gegen
> den **gepushten** Stand, also beide Commits einzeln pushen und den roten Lauf mit seinen Zahlen
> festhalten — er ist die Reproduktion und gehört in den PR-Body. CI läuft ohnehin nur auf dem Kopf des
> Pull Requests, ein roter Zwischen-Commit erzeugt also keinen roten Lauf.

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

> 🔴 **Mutationsfest heisst nicht, dass der Test den Produktivpfad trifft.** Die Mutationsprobe belegt,
> dass die Zusicherung scharf ist — nicht, dass der geprüfte Zustand im Betrieb überhaupt vorkommt. Vor
> dem Schreiben deshalb die **Aufrufkette rückwärts** verfolgen: welche Zustände erreichen diese Stelle?
> Gemessen 2026-08-21 (`schn_ivena#83`): drei Tests prüften `Pzc='' ∧ Prio<=0` und wurden in der
> Mutationsprobe alle brav rot — trotzdem ist der Zustand produktiv unerreichbar, weil ein vorgelagerter
> Guard (`IsValidForZuweisung`, an allen drei TaskHandler-Einstiegen) ihn ausschliesst. Der erreichbare
> gefährliche Fall lag daneben, auf einem zweiten Pfad, und war ungetestet. Gefunden hat das der lokale
> Review-Agent, nicht die grüne Suite.
>
> Zwei Folgerungen: **Vertrags-Tests behalten, aber als solche kennzeichnen** („Tiefenverteidigung,
> produktiv nicht erreichbar") und den erreichbaren Fall **zusätzlich** abdecken. Und **jeden Sentinel
> einzeln** prüfen — hat ein Feld zwei „ungültig"-Werte (dort `0` aus einem wörtlichen DB-Wert und `-1`
> als „nicht gesetzt"), fängt ein Guard `<> 0` den einen ab und lässt den anderen durch; mit nur einem
> geprüften Sentinel sieht das kein Test.

> ⚠️ **Eine Mutation wirkt erst, wenn sie gepusht ist.** `edp-ctrl dev test` synchronisiert den
> **gepushten** Branch auf die VM — eine nur lokal gesetzte Mutation ist für den Lauf unsichtbar, und das
> Ergebnis liest sich wie „der Test hält". Dafür einen **Wegwerf-Branch** nehmen (`tmp/<vorgang>-…`),
> nicht den Fix-Branch, und ihn danach lokal **und** auf `origin` löschen. Vorher prüfen, dass das Präfix
> keinen Workflow triggert: in den `schn_*`-Repos läuft `ci.yml` nur auf `pull_request`, und
> `delivery.yml` baut auf `feature/**`, `bugfix/**`, `hotfix/**`, `project/**` — ein `tmp/**` löst nichts
> aus und hinterlässt damit auch kein Waisen-Release.

> ⚠️ **Zum Zurückbauen einer Mutation NIE `git checkout -- <datei>`.** Das stellt aus dem **Index** her und
> verwirft dabei stillschweigend jede noch nicht committete Änderung in derselben Datei — in diesem Lauf
> ist so eine frisch geschriebene Funktion verschwunden. Stattdessen **vor** der Mutationsreihe committen
> oder die Datei nach `$CLAUDE_JOB_DIR/tmp` kopieren und von dort zurückspielen.

> 🔴 **„Wird es rot?" ist nur die halbe Mutationsprobe — und ein rot gewordener Lauf belegt oft etwas
> anderes als die eigene Änderung.** Zwei Lücken, beide am 2026-08-21 in `installer#94` bezahlt:
>
> 1. **Rot ≠ mein Test war es.** Das auskommentierte Tag-Muster machte die Suite rot (12 Tests) — aber
>    ausschliesslich über vorbestehende **funktionale** Tests; die frisch verschärfte Zusicherung blieb
>    grün und hätte die Mutation nie bemerkt. Die Probe „hat bestanden" und bewies nichts. Also nicht nur
>    die **Zahl** roter Tests lesen, sondern ihre **Namen** — und dabei prüfen, ob die eigene Zusicherung
>    darunter ist.
> 2. **Eine Verschärfung kann eine neue Falsch-Rot-Klasse einführen.** Aus `> 0` wurde `-Be n`; damit
>    wurde eine bis dahin folgenlose Ungenauigkeit wirksam (der Helfer zählte Treffer in Kommentaren mit)
>    und ein harmloser erklärender Kommentar färbte die CI rot. Die Probe muss deshalb **in beide
>    Richtungen** laufen: *wird es rot, wenn der Gegenstand kaputtgeht?* **und** *bleibt es grün, wenn
>    jemand etwas Harmloses tut?*
>
> Beides entscheidet sich erst im **A/B gegen die Fassung vor der Änderung**: dieselbe Mutation einmal
> gegen den alten und einmal gegen den neuen Test fahren. Nur der Unterschied zwischen beiden Läufen ist
> der Beleg — ein einzelner roter Lauf ist keiner. Die Tabelle mit beiden Spalten gehört in den PR-Body.
>
> Verwandt, eine Ebene höher: [[tim/feedback/pruefungen-muessen-sich-selbst-erklaeren]] — dort auch der
> Befund, dass der **Behebungsvorschlag** einer Prüfung selbst ein Prüfgegenstand ist. Im selben Lauf
> riet die Meldung, „die erwartete Anzahl anzupassen"; `Anzahl = 0` war gültig und machte die Prüfung
> lautlos wirkungslos. Den eigenen Rat also durchspielen, als befolge ihn jemand wörtlich und faul — und
> den entwertenden Randfall nicht nur in Prosa ausschließen, sondern **hart** (eigene Zusicherung auf
> die Konfiguration).

> ⚠️ **Die Vorfassung für das A/B byte-genau zurückspielen — und die Testanzahl mitlesen.**
> `git show <ref>:<datei> | Set-Content -Encoding utf8BOM` erzeugt einen **doppelten BOM**: `git show`
> gibt den Blob unverändert aus, der Writer setzt einen zweiten davor. Das zweite Zeichen steht dann vor
> dem ersten Token, Pester findet **keinen einzigen Test** und meldet `Total=0 Failed=0` — was jede
> Auswertung auf `Failed -eq 0` als **grün** liest. Gemessen 2026-08-21 (`installer#94`): der „grüne"
> A/B-Lauf hatte gar nichts gemessen.
>
> Richtig: `git show "<ref>:<pfad>" > <datei>` (byte-genau umleiten, Anführungszeichen wegen zsh) und
> `head -c 6 <datei> | xxd` gegenlesen. Und **jede** Auswertung eines Testlaufs prüft `TotalCount`
> zusätzlich zu `FailedCount` — ein Lauf ohne Tests ist kein grüner Lauf. Weitere Fälle derselben Bauart:
> `$VAULT/referenz/stille-messfallen-shell-git.md`.

> 🔴 **Dateiinhalte NIE per `base64 -d` aus der Contents-API lesen, ohne die Vollständigkeit zu prüfen.**
> `gh api ".../contents/<pfad>" --jq .content | base64 -d` kann **still abbrechen** und einen Teil der
> Datei liefern. Das Ergebnis einer Suche darin („kein Treffer") ist von einem echten Nicht-Vorkommen
> **nicht zu unterscheiden**.
>
> Gemessen 2026-08-21 (`.github#147`): bei `edp/edpserver-delphi` wurden 58 von 69 Zeilen dekodiert —
> abgeschnitten war ausgerechnet der gesuchte Eintrag. Folge: ein Issue in einem Repo, das gar keinen
> Mangel hatte, plus eine falsche Kopfzahl in Dokument, PR-Body und sieben weiteren Issue-Bodies, die
> alle nachgezogen werden mussten.
>
> Richtig ist der Rohabruf **plus Grössenabgleich** — die Metadaten nennen die Soll-Grösse:
>
> ```bash
> soll=$(gh api --hostname <host> "repos/<org>/<repo>/contents/<pfad>?ref=<branch>" --jq .size)
> ist=$(gh api --hostname <host> -H "Accept: application/vnd.github.raw" \
>         "repos/<org>/<repo>/contents/<pfad>?ref=<branch>" | wc -c)
> ```
>
> Weichen sie ab, ist die Messung ungültig — **nicht** der Befund. Dieselbe Bauart wie die anderen
> stillen Nullen: `$VAULT/referenz/stille-messfallen-shell-git.md`.

> ⚠️ **Zwei weitere stille Nullen bei `gh`, beide in diesem Lauf zugeschlagen:**
>
> - **Die Codesuche ist indexbasiert und hinkt hinterher.** `search/code?q=org:…+path:tests` lieferte
>   eine Repo-Liste, in der ein Repo fehlte, dessen Suite wenige Stunden alt war — und zeigte umgekehrt
>   noch die alte Fassung einer Datei, deren Korrektur-PR bereits offen war. Für „gibt es X im Baum?"
>   gehört der **Baum** gelesen (`contents`/`git/trees`), nicht der Index. Die Codesuche taugt zum
>   *Finden von Kandidaten*, nie als Bestandsaufnahme.
> - **`gh api … -q` schreibt die 404-JSON auf stdout.** Eine Existenzprüfung per „Ausgabe leer?" meldet
>   den Branch deshalb als vorhanden; das dichtete einem Repo ein `beta`/`release` an, das es nicht hat.
>   Belastbar ist nur der Status: `gh api --silent … >/dev/null 2>&1`.

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

> 🔴 **Die erste verändernde Aktion an das ERGEBNIS des check-and-set binden, nicht bloss dahinter
> schreiben.** Der Lock-Aufruf liefert „GESETZT" oder „BELEGT" — steht die Mutation (ein `scp` auf die
> VM, ein `compile`) unbedingt im selben Block dahinter, läuft sie auch bei „BELEGT". Gemessen
> 2026-08-21 (`edp-ctrl#47`): der Lock war zwischen zwei Schritten von einer parallelen Session
> übernommen worden, die Testdatei landete trotzdem im VM-Projektverzeichnis und musste sofort wieder
> weg, bevor sie deren Bau verfälscht. Also: Lock holen, Antwort **lesen**, erst dann mutieren — und
> bei „BELEGT" warten statt weiterzumachen. Der Lock kann auch **mitten im Lauf** den Halter wechseln;
> vor einer späteren Messrunde neu holen, nicht auf den Stand von vorhin vertrauen.

> 🔴 **Ein gescheiterter `dev compile` heisst nicht „auf der Dev-VM ist nichts messbar".** Zwei Schritte,
> bevor daraus ein Blocker im Bericht wird:
>
> 1. **Gegen die Baseline gegenprüfen** — denselben Bau auf unverändertem `origin/dev` fahren
>    (Haupt-Klon, `--project-root ~/dev/EDP`). Zeilengleicher Fehler = vorbestehend, nicht aus dem
>    eigenen Diff. Ohne diese Probe steht im Bericht ein Fehler, den man selbst verursacht zu haben
>    scheint.
> 2. **Prüfen, was trotzdem läuft.** Ein Bau scheitert an **einer** fehlenden Komponente in **einer**
>    Unit; alles, was diese Unit nicht linkt, übersetzt weiterhin. Gemessen 2026-08-21
>    (`einsatzmonitor#10`): `dev compile` bricht in `ufrmmain.pas` an `AdvMetroButton` ab (TMS auf der
>    Dev-VM nicht provisioniert, `edp/delphi-devsetup#31`) — `edp-ctrl dev test` derselben Repo lief
>    dagegen durch, weil das Testprojekt `ufrmmain` nicht linkt. Die geänderten Units waren damit
>    übersetzt **und** gemessen; nur für die restlichen trug `delphi / build` des Pull Requests den
>    Nachweis.
>
> Ein Testprojekt braucht **kein** vorheriges `compile`, solange es seine Produktivquellen selbst
> übersetzt (eigener `DCC_DcuOutput`). Die Regel „erst `compile`, dann `test`" gilt dort, wo die Suite
> die `Win64\Release`-DCUs des Hauptbaus mitbenutzt — das vorher an der `.dproj` ablesen statt
> anzunehmen.

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
>
> 🔴 **Und prüfen, ob das Kriterium überhaupt erfüllbar ist — manche sind es wörtlich nicht.** Gemessen
> 2026-08-21 (`installer#94`): gefordert war, dass `grep -rn 'Produktliste' --include='*.md' --include='*.yml'
> --include='*.ps1' .` nach dem Löschen von `tests/Produktliste.Tests.ps1` **keinen Treffer** liefert. Der
> Suchbegriff ist aber zugleich ein gewöhnliches deutsches Wort und stand zweimal in völlig korrekter Prosa
> („die Workflows lesen die Produktliste aus dem Verzeichnis"). Wörtlich erfüllbar wäre das Kriterium nur,
> indem man richtigen Text verstümmelt.
>
> In so einem Fall **nicht** stillschweigend das Kriterium umdeuten und auch nicht den Code danach biegen:
> die engere, tatsächlich gemeinte Fassung ausführen (hier `grep -rn 'Produktliste\.Tests'`), die
> verbleibenden Treffer **einzeln zitieren** und die gewählte Lesart in **Issue-Kommentar und PR-Body**
> begründen. Ein Kriterium ist eine Absicht in Kommandoform — trifft das Kommando mehr als die Absicht,
> gewinnt die Absicht, aber nur ausgesprochen.

> 🔴 **Wo ein CI-Artefakt vorliegt, wird AM ARTEFAKT gemessen — ein selbst nachgebautes Erzeugnis ist
> eine Hypothese über den Bau, kein Beleg.** Der Delphi-Lauf hängt das Bauergebnis an
> (`einsatzmonitor-artifacts`, `<repo>-testreport`, bei edpweb entsprechend); `gh run download <run-id>
> -R einsatzleitsoftware.ghe.com/edp/<repo> -n <name>` holt es auf den Linux-Rechner, und dann lässt sich
> die Frage „steckt X wirklich drin?" byte-genau beantworten, statt sie zu vermuten. Vorher an den Lauf
> kommen: `gh api "repos/edp/<repo>/actions/runs/<id>/artifacts" --hostname einsatzleitsoftware.ghe.com`.
>
> ⚠️ **Und die Zeilenenden-Falle dabei kennen.** Wer Quelldateien vom Linux-Rechner auf die Dev-VM kopiert
> (`scp`) und dort ein Werkzeug darüber laufen lässt, misst an **LF**-Eingaben. Der Windows-Läufer checkt
> mit `autocrlf` aus und arbeitet mit **CRLF** — solange keine `.gitattributes` das festnagelt. Ein
> Erzeugnis, das so nachgebaut wurde, weicht dann vom echten Bauergebnis ab, **ohne** dass irgendetwas
> defekt wäre. Gemessen 2026-08-21 (`einsatzmonitor#12`): daraus wurde die falsche Aussage, eine
> eingecheckte `.RES` sei von ihren Quellen abgedriftet — sie war aktuell, das CI-Artefakt enthielt alle
> sieben Abschnitte bytegleich. Drei Aufrufformen desselben Werkzeugs hatten das übereinstimmend
> „bestätigt": **alle drei bekamen dieselben LF-Eingaben**, variiert war der Aufruf statt der Grösse, an
> der die Aussage hing ([[tim/feedback/urteil-braucht-vollstaendige-messung]]). Vor dem Variieren also
> fragen, **welche Grösse die Aussage trägt** — und die variieren.

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
> 2. **edpweb-DUnitX-Suite nach einem vorherigen `compile` fahren** — das Test-`.dproj` ist
>    Win64-orientiert und reused die `..\Win64\Release`-DCUs des Haupt-Builds (inkl. CCR.Exif).
>    ⚠️ **`--platform Win64` NICHT mehr von Hand setzen — hier stand jahrelang das Gegenteil.** `edp-ctrl
>    dev test` defaultet seit Commit `4692d76` (Issue #22 / PR #23, in `dev` am 2026-07-23) selbst auf
>    Win64, ausgeliefert ab **v0.2.0**; nachgemessen 2026-08-21 an `cmd_dev.go` und
>    `git tag --contains`. Nur ein Uralt-Binary (≤ v0.1.1) braucht das Flag noch. Ein `F2048`/`F2613`
>    beim Testbau bleibt trotzdem erkennenswert: es heisst Plattform-Mismatch zwischen Haupt-Build und
>    Testbau und hat **nichts** mit dem eigenen Fix zu tun.
>    Details: [[projekte/edpweb/dunitx-test-harness-pickup]].
> 3. 🔴 **Nach der Lock-Freigabe KEINE Messung mehr gegen die VM — auch keine lesende.** Sobald der Lock
>    weg ist, deployt eine andere Session sofort ihren Branch. Eine Messung danach misst fremden Code, und
>    das Fehlerbild zeigt auf den **eigenen**: Gemessen 2026-08-19 (#413) kam nach der Freigabe ein
>    `EINSATZNUMMER = NULL` zurück, wo eben noch der Wert stand, plus ein 500 auf dem eigenen
>    JSON-Endpunkt — beides sah nach Regression im eigenen Fix aus und war ein anderer Stand
>    (`git log -1` im VM-Projektverzeichnis zeigte einen fremden Branch). Also **alle** Messungen innerhalb
>    der eigenen Lock-Zeit abschliessen; muss später nachgemessen werden, erst den Lock wieder holen und den
>    deployten Branch gegenlesen. Reine CSS-/Farbfragen brauchen die VM ohnehin nicht — dafür
>    `$VAULT/referenz/edpweb-testing/frontend-ui-harness.md`.

> **Ist das Repo unter Prüfung `edp-ctrl` selbst, dreht sich `/edp-develop` um.** Das Werkzeug *steuert*
> die Dev-VM, es läuft nicht auf ihr — „auf die VM deployen" gibt es hier nicht. Verifikation stattdessen:
> Binary lokal bauen (`go build -o <tmp>/edp-ctrl-fix .`) und **gegen die echte VM** fahren. Der stärkste
> Beleg ist ein **A/B im selben Lock-Fenster**: altes Binary aus `origin/<base>` und neues direkt
> hintereinander mit demselben Kommando messen. Über zwei Lock-Fenster hinweg ist ein A/B wertlos, sobald
> eine parallele Session dazwischen deployt ([[tim/feedback/dev-vm-exklusiv-belegen]]). Fehlerpfade, die
> die VM gar nicht brauchen (unerreichbarer Host, DNS), laufen ohne Lock — dann auch nicht darauf warten.
> Für einen **dauerhaften `sc`-Fehler** ohne Dienst-Manipulation: `sc query \\10.255.255.1` liefert
> reproduzierbar `[SC] … FEHLER 123:`, rein lesend (gemessen 2026-08-21, `edp-ctrl#28`).
>
> **Den Fall auf der echten VM herstellen, ohne ein Repo anzufassen:** `gitSyncVM` fährt `fetch` +
> `checkout -B` + `reset --hard`, aber **kein `git clean`** — eine **untrackte** Datei im
> VM-Projektverzeichnis überlebt den Sync. Damit lässt sich eine Bedingung, die kein echtes Projekt
> hergibt (etwa eine `package.json` ohne das gesuchte Skript), per `scp` setzen und danach wieder
> entfernen. Vehikel ist ein **kleines Delphi-Projekt ohne Dienst** — `ServiceForProject` liefert nur
> für `edpweb` und `server`/`schn_*` einen Namen, der Dienst-Bounce entfällt sonst. Achtung: den
> Frontend-Bau ruft **nur `compileDelphi`** auf, ein Go-Projekt läuft nie durch diesen Pfad. Rezept
> und Fallen: `$VAULT/projekte/edp-ctrl/architektur.md`.

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

> **Ausnahme — die Änderung IST die org-weit geteilte CI selbst** (`edp/.github`: ein `checks-*.yml`,
> eine Action unter `actions/`, eine Vorlage unter `workflow-templates/`): Ihre Wirkung entsteht erst,
> wenn die Konsumenten sie mit `@dev` ziehen — also **nach** dem Merge. Das Repo-Gate von `edp/.github`
> prüft nur dieses Repo und sagt über die Wirkung nichts. Verifikation dann dreiteilig, und alle drei
> Teile gehören in den PR-Body:
>
> 1. **Die Wirkungsbehauptung offline hart belegen** — nicht „nach dem Merge sieht man's". Beispiel aus
>    `#140`: statt zu behaupten, die Merge-Fassung enthalte die fehlende Testausstattung, die **beiden
>    Bäume gegeneinander messen** (`git ls-tree -r --name-only <kopf-sha> -- tests/` gegen denselben
>    Aufruf auf dem Merge-SHA, dazu `git show "<sha>:<datei>"`). Das ist ein Beleg, kein Versprechen.
> 2. **Fremdes Verhalten am Quellcode des gepinnten Stands nachlesen**, nicht aus dem Gedächtnis — bei
>    `actions/checkout` etwa `ref-helper.ts`/`git-source-provider.ts` am Pin-SHA über
>    `gh api "repos/actions/checkout/contents/<pfad>?ref=<sha>"`. ⚠️ Die URL **quoten**, sonst frisst zsh
>    das `?` als Glob und meldet „no matches found" — ein leeres Ergebnis, das wie ein Nicht-Befund
>    aussieht.
> 3. **Offene Annahmen zu Ende messen und in `docs/ci-gate-struktur.md` § „Belegte Annahmen" eintragen**,
>    mit Datum, Repo und Lauf — so hält es dieses Repo für jede andere Annahme auch. Ein Probier-Repo
>    dafür gibt es: `edp/test` (dort liegen die bisherigen Proben). Eine Messung ohne Datum und Beleg ist
>    in diesem Repo kein Befund, sondern eine Behauptung.
>
> ⚠️ Und die Frage **rückwärts** stellen: wer verlässt sich heute auf das alte Verhalten? In `#140` sprang
> `decide` in `delivery.yml` den Delphi-Bau mit der Begründung ab, „das Gate baut denselben Stand" —
> eine Aussage, die der Fix ungültig macht. Vor dem Push einmal nach Text**trägern** der Zusage suchen, die
> man gerade bricht ([[tim/feedback/korrektur-erreicht-alle-traeger]]).

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
([[tim/feedback/randfunde-als-issue]]). ⚠️ **Erst den Vorgang anlegen, dann seine Nummer irgendwo
referenzieren** — die nächste freie Nummer lässt sich nicht vorhersagen (Issues und PRs teilen sie sich;
in einem Lauf war die geratene bereits vergeben und musste per Folge-Commit korrigiert werden). Das gilt
**in beide Richtungen**: auch eine PR-Nummer gehört nicht in einen Issue-Kommentar, bevor der PR
existiert. Eine geratene Nummer, die zufällig stimmt, ist der schlechtere Ausgang — sie bestätigt das
Raten (gemessen 2026-08-21, `edp-ctrl#47`). Reihenfolge: PR anlegen, Nummer lesen, dann kommentieren.

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

> ⚠️ **Der erste `Merge-Label`-Lauf ist rot — das ist kein Befund.** Der Workflow startet mit dem Pull
> Request, also bevor `--add-label` gelaufen ist, und scheitert mangels `merge:*`-Label. Er heilt sich
> selbst (`labeled` triggert neu), aber ein `gh pr checks` in diesem Fenster zeigt ein Rot, das keins ist.
> Labels deshalb **unmittelbar** nach dem Erstellen setzen und den Check-Stand erst danach bewerten.
> Nebenwirkung: die gleichnamigen Läufe teilen sich die Concurrency-Gruppe, einer endet `cancelled` —
> für die Bewertung zählt allein der jüngste. Gemessen 2026-08-21 (`schn_ivena#128`): vier `Merge-Label`-
> Läufe, `FAILURE` → `CANCELLED` → 2× `SUCCESS`, PR trotzdem `CLEAN`.

### `«ABSCHLUSS»` — merge-ready, Merge macht das Team

Definition of Done ist der **mergebare** Zustand ([[tim/feedback/pr-fertig-erst-wenn-mergebar]]). Den
eigentlichen Merge dem Team/Reviewer überlassen — **nicht selbst mergen**.

> 🔴 **Sonderfall: ein Klammer-Vorgang, der per Fanout in Einzel-Issues aufgelöst und dann geschlossen
> wird.** Manche Vorgänge ändern selbst keine Datei — sie halten eine org-weite Messung, eine Reihenfolge
> und eine Entscheidung fest, und die Arbeit liegt in N anderen Repos. Wird so einer geschlossen, gilt:
>
> 1. **Jedes Akzeptanzkriterium einzeln daraufhin prüfen, ob ein Einzelvorgang es trägt.** Das ist der
>    Schritt, der leicht ausfällt, weil die Repo-Liste vollständig aussieht. Gemessen 2026-08-21
>    (`edp-runtime-redist#15`): drei der vier Kriterien wanderten sauber in die acht Repo-Vorgänge, das
>    vierte — eine Prüfung, die anschlägt, wenn eine Datei wieder in einen Baum kommt — trug **keiner**.
>    Es hätte mit dem Schliessen aufgehört zu existieren. Ein solches Kriterium gehört in das Repo, dessen
>    Mechanismus es prüft (hier `edp-runtime-redist#28`), nicht in eines der Konsumenten-Repos.
> 2. **Was bewusst NICHT weitergegeben wird, im Abschlusskommentar benennen — mit Grund.** Ein Vorbehalt,
>    der nur wegfällt, gilt später als übersehen. Prüffrage: ändert dieser offene Punkt die *Handlung* oder
>    nur die *Dringlichkeit*? Nur die Dringlichkeit → benennen und der Priorisierung überlassen.
> 3. **Die Einzelvorgänge tragen den Ist-Wert, nicht nur einen Verweis.** Wer `#5` in seinem Repo öffnet,
>    darf nicht erst den geschlossenen Klammer-Vorgang lesen müssen: Fundstellen, Fassung, Prüfsumme,
>    Auslieferungsweg, `## Branch & Cascade` und ein Laufzeit-Akzeptanzkriterium gehören in **jeden**
>    Einzelvorgang. Der Rückverweis (`Ref <org>/<klammer>#NN`) kommt zusätzlich.
> 4. **Bei Überschneidung mit bestehenden Vorgängen dort kommentieren, nicht nur im neuen Issue.** Vier der
>    acht Repos hatten schon einen offenen oder geschlossenen Vorgang am selben Gegenstand; ohne Kommentar
>    dort arbeitet der Nächste doppelt oder hält den geschlossenen für erledigt
>    ([[tim/feedback/korrektur-erreicht-alle-traeger]]).

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
> Das gilt auch für **Zahlen** im Issue: eine genannte Wartezeit/Dauer ist eine Messung unter *einer*
> Fehlerart, nicht die Obergrenze. Gemessen 2026-08-21 (`edp-ctrl#28`): der Titel nannte einen 41-s-Hänger
> — bei nicht routbarer Ziel-IP waren es **251 s**, weil je Versuch der volle `ConnectTimeout` lief. Die
> teuerste Variante derselben Fehlerklasse selbst suchen, bevor man Aufwand oder Dringlichkeit einschätzt.
>
> Ergebnis der Nachmessung gehört als Kommentar ans Issue (Kriterium für Kriterium: erledigt / offen, je
> mit Beleg) — das ist zugleich das Gerüst für den späteren PR-Body.
>
> 🔴 **Auch den REFERENZWERT nachmessen, gegen den das Issue seine Funde bewertet — nicht nur die Funde.**
> Ein Issue vergleicht fast immer gegen etwas: eine Soll-Version, einen Pin, einen kanonischen Stand, eine
> Vorlage. Dieser Bezugspunkt altert genauso wie die Fundstellen, nur **unsichtbar**: die Fundliste stimmt
> weiter, ihre *Einstufung* kippt. Ein „stimmt alles noch"-Abgleich der Fundstellen bestätigt den Vorgang
> dann fälschlich.
>
> Gemessen 2026-08-21 (`edp-runtime-redist#15`): der Body nannte Bundle `v1.2.0`/OpenSSL 3.5.1 als Soll und
> stufte damit `edpweb@release`, `setups` und `tool-abrechnungstool` als **kanonisch** ein — sie standen
> nicht auf der Arbeitsliste. Zentral galt längst `v1.4.0`/OpenSSL 3.5.5; dieselben, völlig unveränderten
> Dateien waren damit abweichend. Der Vorgang wuchs von **5 auf 8 betroffene Repos**, und die Nachmessung
> nur der genannten Fundstellen hätte drei Repos still ausgelassen.
>
> Daraus zwei Regeln:
>
> 1. **Erst die Referenz messen, dann die Funde.** Bei einer Fassungs-/Pin-Frage heisst das: die zentrale
>    Deklaration am heutigen Stand lesen, nicht die Zahl aus dem Body übernehmen.
> 2. **Hat sich die Referenz bewegt, ist die ganze Erhebung zu wiederholen** — nicht nur die Liste
>    abzugleichen. Nur der volle Lauf zeigt die Fälle, die durch die Bewegung **neu** hineingerutscht sind.
>    Er zeigt auch die, die seit der Erhebung erst entstanden sind: `edp/Schn_Icon_RUC` war fünf Tage nach
>    der ursprünglichen Messung angelegt worden und brachte den Altbestand gleich mit.
>
> ⚠️ **Eine Datei in Git LFS lässt sich nicht über die Contents-API messen** — die liefert den Zeiger, und
> `git lfs pull` scheitert im frischen Klon still (kein Fehler, keine Datei). Der Weg, der trägt:
>
> ```bash
> TOK=$(gh auth token --hostname einsatzleitsoftware.ghe.com)
> RESP=$(curl -s -u "x-access-token:$TOK" \
>   -X POST "https://einsatzleitsoftware.ghe.com/edp/<repo>.git/info/lfs/objects/batch" \
>   -H 'Accept: application/vnd.git-lfs+json' -H 'Content-Type: application/vnd.git-lfs+json' \
>   -d "{\"operation\":\"download\",\"transfers\":[\"basic\"],\"objects\":[{\"oid\":\"<oid>\",\"size\":<size>}]}")
> curl -sL -H "Authorization: $(echo "$RESP" | jq -r '.objects[0].actions.download.header.Authorization')" \
>   "$(echo "$RESP" | jq -r '.objects[0].actions.download.href')" -o datei.bin
> ```
>
> `oid` und `size` stehen im Zeiger selbst. Für einen reinen **Inhaltsvergleich** braucht es das gar nicht:
> die `oid sha256` des Zeigers **ist** der SHA256 des Inhalts und lässt sich direkt gegen eine deklarierte
> Prüfsumme stellen. Materialisieren muss man nur, wenn man *in* die Datei sehen will (PE-Versionsblock,
> Architektur).
>
> ⚠️ Und eine stille Falle beim Auswerten der Trees-API: `jq -r '.truncated // "n/a"'` liefert für den
> Normalfall `false` die Zeichenkette `"n/a"` — `//` behandelt `false` wie „leer". Wer so auf abgeschnittene
> Antworten prüft, bekommt nie ein `false` zu sehen und hält die Prüfung für nicht verfügbar. Richtig ist
> `jq -r 'if .truncated then "TRUNCATED" else "ok" end'`.
>
> 🔴 **Und die im Issue behauptete URSACHE genauso nachmessen wie die Fundstellen.** Ein Melder beschreibt
> zuverlässig, *was* er gesehen hat; *woher* es kommt, ist seine Hypothese — und die zeigt naturgemäß auf
> die Stelle, an der es weh tat, nicht auf die, an der es entsteht. Den Code-Pfad deshalb einmal
> **rückwärts** vom Fehlerpunkt zur Quelle verfolgen, statt am benannten Ort mit dem Beheben anzufangen.
>
> Gemessen 2026-08-21 (`edp/.github#140`): das Issue verortete den Defekt im Checkout-Ref der
> **Delphi-Stufe**. Tatsächlich nahm die gar keinen eigenen Rückfall — der falsche Wert kam aus der
> Formatier-Ebene und traf **alle** Prüf-Ebenen gleichermaßen; Delphi fiel nur als erste hart auf, weil sie
> als einzige eine *Ausstattung* braucht, die fehlen kann. Ein Fix an der benannten Stelle hätte den
> Auslöser beseitigt und die Ursache stehen lassen — Go und Frontend prüften weiter still den falschen
> Baum. Prüffrage: *ist die benannte Stelle die einzige Betroffene, oder nur die lauteste?* Wenn ein
> Mechanismus geteilt ist, gehört der Fix an die Wurzel ([[tim/feedback/generisch-ueber-oekosysteme]]).

## Zusatz zu Core-Schritt 8b (CI beobachten)

> ⚠️ **`gh pr checks` liefert direkt nach einem Push eine unvollständige Liste.** Eine Abbruchbedingung
> „alle Checks sind nicht mehr `pending`" ist dann **trivial erfüllt** und meldet grün, während der Lauf
> gerade erst anläuft. In diesem Lauf hat genau das einmal ein falsches „alle Checks abgeschlossen" mit
> einem einzigen Check erzeugt.
>
> Belastbar ist erst: **der Aggregat-Check ist in der Liste vorhanden UND nicht mehr `pending`**,
> zusätzlich die Gesamtzahl der Checks gegenlesen (in `edp/datenbank` sind es 14). Was ihn nicht
> enthält, ist keine Aussage über den Lauf.
>
> 🔴 **Der Aggregat-Check heisst NICHT überall `ci-summary`.** In `edp/.github` ist es **`repo-summary`**
> — dessen `gate.yml` begründet das ausdrücklich: das Repo ist weder ein Delphi- noch ein Go-Projekt und
> darf keinen der beiden Sprach-Kontexte belegen. Wer dort auf `ci-summary` wartet, wartet auf einen
> Kontext, den es nie geben wird. Den Namen also aus dem Repo ablesen (`grep -n 'summary:' \
> .github/workflows/gate.yml` bzw. `ci.yml`), nicht annehmen.
>
> Und **`no checks reported on the '<branch>' branch` ist kein Fehler**, sondern der Zustand vor dem
> Anlaufen — `gh pr checks --watch` beendet sich in diesem Fenster sofort mit Status 0. Deshalb nicht auf
> `--watch` allein bauen, sondern auf eine Bedingung warten, die den Aggregat-Check **nennt**:
>
> ```bash
> until out=$(gh pr checks <nr> -R einsatzleitsoftware.ghe.com/edp/<repo> 2>/dev/null) \
>       && echo "$out" | grep -q '<aggregat-check>' && ! echo "$out" | grep -q 'pending'; do sleep 15; done
> ```

> 🔴 **Ein grünes `ci-summary` belegt NICHT, dass Tests gelaufen sind — und es gibt oft gar keinen
> Test-Check.** Die Delphi-Suite läuft **innerhalb** von `delphi / build` als Phasen `TestBuild`/`TestRun`;
> in der Check-Liste taucht sie nicht auf. Wer nach `delphi / test` sucht, findet nichts und darf daraus
> **nicht** schliessen, dass nicht getestet wurde — und umgekehrt ist der grüne Haken von `delphi / build`
> kein Beleg, dass getestet **wurde**. Beides entscheidet allein das Job-Log:
>
> ```bash
> ID=$(gh run list -R einsatzleitsoftware.ghe.com/edp/<repo> --branch <branch> --workflow CI \
>        --limit 1 --json databaseId -q '.[0].databaseId')
> gh run view $ID -R einsatzleitsoftware.ghe.com/edp/<repo> --log \
>   --job=$(gh run view $ID -R einsatzleitsoftware.ghe.com/edp/<repo> \
>             --json jobs -q '.jobs[] | select(.name=="delphi / build") | .databaseId') \
>   | grep -aE 'RUN_TESTS|Führe Tests aus|Tests (Found|Passed|Failed)|TESTS GRÜN'
> ```
>
> Erwartet werden `RUN_TESTS: true`, die Zeile `Führe Tests aus: …\<Repo>Tests.exe` und eine
> **`Tests Found` grösser null**. Fehlt `run-tests` in der `ci.yml` bei vorhandenem `Test`-Block, wird die
> Suite nicht einmal übersetzt und der Lauf ist grün, ohne dass ein Test lief — der stille Fall aus
> `edp/.github` > `docs/delphi-test-standard.md`. Der Auszug gehört in den PR-Body, nicht der grüne Haken.

> ⚠️ **Im Job-Log gibt es keinen Schritt namens `Build` — der Hauptbau läuft unter `TestBuild`.** Die
> Engine fährt `Repos`, `DelphiConfig`, `BuildPackages`, `TestBuild` und (bei `run-tests: true`) `TestRun`.
> `TestBuild` baut das **Produktivziel**, nicht ein Testprojekt: `TestBuild: 1 Ziel(e) — <projekt>` →
> `TESTBUILD GRÜN — <projekt> gebaut!` → `<projekt>.exe (… MB) → _ci-out/`. Wer nach „Build" greppt,
> findet nichts und schliesst falsch, der Hauptbau liefe am Pull Request nicht mit.
>
> Das ist deshalb wichtig, weil `delphi / build` damit **der** Nachweis für alles ist, was die Dev-VM
> nicht bauen kann (fehlende Komponente, siehe `«VERIFY»`). Gemessen 2026-08-21 (`einsatzmonitor#12`,
> Lauf `208747682`): die Dev-VM scheitert an TMS, der PR-Lauf baute die `einsatzmonitor.exe` trotzdem
> vollständig — die Aussage „auf der Dev-VM nicht prüfbar" heisst also nicht „im PR nicht geprüft".

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

## Zusatz zu Core-Schritt 8c (lokales Review)

> 🔴 **Ändert die Review-Runde das Verhalten, sind die im PR-Body zitierten Belege selbst Träger einer
> überholten Aussage.** Ein Ausgabe-Block, ein Log-Auszug, eine Mutationstabelle im PR-Body war eine
> Messung am Stand von vorhin — nach einem Fix-Push stimmt sie womöglich nicht mehr, und niemand sieht
> es ihr an. Nach jeder Review-Runde deshalb prüfen, welche zitierten Belege der Fix ungültig gemacht
> hat, und sie **neu messen** statt sie stehen zu lassen ([[tim/feedback/korrektur-erreicht-alle-traeger]]).
> Gemessen 2026-08-21 (`edp-ctrl#47`): das Review änderte den Meldungstext, der PR-Body zitierte weiter
> die alte Zeile aus dem VM-Lauf — der Nachweis wurde auf der Dev-VM wiederholt und ersetzt.
>
> Die Review-Notiz an den PR nennt **auch die Funde ohne Befund** („geprüft und in Ordnung") — sie sagt
> dem menschlichen Reviewer, was er *nicht* mehr selbst durchgehen muss, und ist damit die halbe
> Ersparnis.

> 🔴 **Wer einem Review-Fund widerspricht, muss die Gegenprobe ANDERS konstruieren als die
> ursprüngliche Messung.** Der Core verlangt, Funde selbst zu verifizieren statt sie blind zu
> übernehmen — das schützt vor falschen Funden, aber nicht vor dem teureren Fall: einen **richtigen**
> Fund zurückzuweisen, weil die Gegenprüfung denselben Fehler wiederholt wie die Messung, die den
> Fehler erzeugt hat.
>
> Gemessen 2026-08-21 (`.github#147`): Der Agent meldete, ein Repo sei fälschlich als betroffen
> gelistet. Die Gegenprüfung „ich habe dort doch 0 Treffer gemessen" nutzte **dieselbe** still
> trunkierende Dekodierung wie die Ersterhebung und bestätigte den eigenen Fehler. Erst eine anders
> gebaute Messung (Rohabruf mit Grössenabgleich) zeigte, dass der Agent recht hatte. Zwischen beiden
> Schritten stand bereits ein veröffentlichtes „der Agent irrt" — Widerspruch ist billig, seine
> Rücknahme nicht.
>
> Prüffrage vor jedem „das stimmt nicht": *Nutze ich gerade dieselbe Quelle, dasselbe Werkzeug und
> denselben Aufruf wie beim ersten Mal?* Wenn ja, ist es keine Gegenprobe, sondern eine Wiederholung
> ([[tim/feedback/urteil-braucht-vollstaendige-messung]]).
>
> Ein zurückgezogener Fehlbefund wird **sichtbar** korrigiert, nicht stillschweigend: Kommentar am
> betroffenen Vorgang mit der Ursache, Vorgang schliessen (`--reason "not planned"`), und **jeden**
> weiteren Träger der falschen Angabe nachziehen — Dokument, PR-Body, alle abgeleiteten Issues
> ([[tim/feedback/korrektur-erreicht-alle-traeger]]).

> **Keine Momentaufnahme in ein Standard-/Vorlagen-Dokument schreiben.** Ein Zählstand („N von M Repos
> führen X") ist beim Lesen schon veraltet und wird als Bestandsaufnahme missverstanden — „die anderen
> sind versorgt". In diesem Lauf änderte sich die Grundmenge an einem einzigen Tag zweimal. Entweder die
> Zahl weglassen **und die Auslassung im Text begründen**, damit sie niemand in gutem Glauben wieder
> einsetzt, oder sie mit Datum und Messweg als klar erkennbare Momentaufnahme kennzeichnen. Für den
> PR-Body gilt das Gegenteil: dort ist die Zahl mit Datum genau richtig.

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

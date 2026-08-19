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

- Env: `EDP_VM_HOST`, `EDP_PROJECT_ROOT` (Mac-Setup + Fallen: `$VAULT/referenz/edp-project-root-mac.md`)
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

Den **niedrigsten betroffenen Branch** (Fall A–D) und den Cascade-Pfad bestimmen — verbindlich aus der
repo-eigenen `docs/GIT.md`, ergänzt durch `$VAULT/referenz/edp-schnittstellen-branch-konvention.md`,
`$VAULT/projekte/edpweb/architektur.md` (Branching) und [[tim/feedback/issue-fix-branch-cascade-festhalten]].
Fix-Branch von der korrekten Basis anlegen (nie auf den Default-Branch direkt committen).

Beim Erfassen (Core-Schritt 1) eine im Issue-Body bereits vorhandene Sektion **`## Branch & Cascade`**
mitlesen — sie ist die Vorgabe des Melders und wird gegen die eigene Cascade-Prüfung abgeglichen, nicht
blind übernommen.

> ⚠️ **Ein Branch-Hinweis im Issue-Titel/-Text (z.B. `[... (dev)]`) ist nur der Melde-Kontext, NICHT
> zwangsläufig der niedrigste betroffene Branch.** Immer aktiv per `docs/GIT.md` + Cross-Branch-Prüfung
> verifizieren, auf welchem Branch der Bug **tatsächlich zuerst** auftritt (er kann tiefer liegen als
> gemeldet, oder sich seit Ticket-Erstellung verschoben haben). Bei Bugs heißt das: prüfen, ob das
> fehlerhafte Verhalten auch auf `release`/`beta` reproduzierbar ist bzw. ob das betroffene Feature dort
> überhaupt existiert — erst dann steht der Fix-Branch fest.

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

### `«VERIFY»` — ausschließlich Dev-VM

> **Zwingend: Test/Verify NUR in der Dev-Umgebung.** Jede Verifikation läuft gegen den **frisch auf die
> Dev-VM deployten** Stand — Delphi/Frontend via `/edp-develop` (`edp-ctrl dev compile <projekt>`, baut inkl.
> `scss:build`), UI via `/edp-design-loop`, Backend via HTTP-POST/DB-Read-Back **gegen die VM**. Ein lokales
> Render-Harness, ein lokaler Build oder „CI ist grün" sind **KEIN Ersatz** — nur auf der Dev-VM herrschen
> reale Bedingungen, und nur so kann Tim die Änderung **selbst** live ansehen. Also **immer erst deployen,
> dann verifizieren**. Geht der Deploy nicht (VM down, Compile hängt) → transparent melden, nicht mit einer
> lokalen Ersatz-Verifikation kaschieren.

**Die Dev-VM ist exklusiv zu belegen** — `compile`, `test` und `service start|stop` erst nach gesetztem
`C:\vm.lock`, sonst misst eine parallele Session still gegen fremden Code ([[tim/feedback/dev-vm-exklusiv-belegen]]).

**Repro-/Test-Wissen zuerst nutzen, nicht neu erfinden:**
- Backend deterministisch per HTTP-Form-POST: `$VAULT/referenz/edpweb-testing/index.md` (Hub → `setup`, `auth`,
  `snippets`, `actions-<bereich>`, `db-kerntabellen`).
- UI-Reproduktion/Verifikation: `/edp-design-loop` bzw. direkt `/playwright-cli` (Login/Cache-Fallen:
  [[tim/feedback/code-self-check-vor-review]]).
- DB-Read-Back: `/edp-database` + `$VAULT/referenz/edpweb-testing/db-kerntabellen.md`.
- Reproduktion auf Release-/Kundenstand zur Abgrenzung: `$VAULT/referenz/edpweb-demo-instanzen.md`;
  Testdaten/Lage: `$VAULT/referenz/edpweb-demo-lage-reset.md`.
- Repo-spezifische Notes unter `$VAULT/projekte/<repo>/` und `$VAULT/referenz/` (z.B. `delphi-live-debug-vm.md`).

> **Dev-VM-Verifikation — zwei wiederkehrende Vorbedingungen:**
> 1. **Feature-Branch vorher auf `origin` pushen** (alle Repos) — der Git-Sync von `edp-ctrl dev compile`/
>    `test` vergleicht `HEAD..origin/<branch>`; ein nie gepushter Branch bricht mit „unbekannter Commit …
>    origin/<branch>" ab (nicht als VM-/Compile-Fehler fehldeuten).
> 2. **edpweb-DUnitX-Suite mit `--platform Win64` fahren, nach einem vorherigen `compile`** — das
>    Test-`.dproj` ist Win64-orientiert und reused die `..\Win64\Release`-DCUs des Haupt-Builds (inkl.
>    CCR.Exif). Der `edp-ctrl dev test`-Default Win32 scheitert sonst mit `F2048`/`F2613`, was **nichts**
>    mit dem Fix zu tun hat. Details: [[projekte/edpweb/dunitx-test-harness-pickup]].

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

## Zusatz zu Core-Schritt 4 (Feature)

> **Berührt das Issue eine Oberfläche, ist `edp-frontend-design` verbindlich** — auch bei einem
> reinen „Feld ergänzen". Er hält den EDP-Kanon (Fluent 2 als Vorbild, Primary abgeschafft zugunsten
> von Secondary, keine Versalien/Sperrung, Weißraum statt Linien) und verweist auf die belegten
> Fluent-2-Werte in `$VAULT/referenz/fluent2-design.md`. Nicht den generischen
> `frontend-design:frontend-design` direkt nutzen — `edp-frontend-design` zieht ihn selbst als Basis heran.

Abschließend `skill-optimize` mit `edp-issue` aufrufen.

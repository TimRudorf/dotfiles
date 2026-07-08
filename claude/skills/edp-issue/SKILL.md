---
name: edp-issue
description: >-
  Autonomer End-to-End-Orchestrator für ein GHE-EDP-Issue (Bug oder Feature). Nutzen, wenn Tim eine
  GHE-Issue-Nummer oder -URL (z.B. https://einsatzleitsoftware.ghe.com/edp/edpweb/issues/369) übergibt und
  sie gelöst haben will. Trigger: "fix issue", "setz das Issue um", "bearbeite Issue #NN", "lös das Ticket im
  Repo", eine reine edp-GHE-Issue-URL/-Nummer, "/edp-issue". Versteht das Issue inkl. aller Verlinkungen
  (auch Zammad), reproduziert Bugs automatisch, findet die Fehlerquelle, plant + implementiert den Fix bzw. das
  Feature nach den Git-/Branch-Cascade-Konventionen, ergänzt Tests, verifiziert end-to-end, hält Issue + Doku
  aktuell, erstellt den PR und treibt ihn über CI- und Copilot-Review-Loop bis zur Mergebarkeit. Läuft voll
  autonom bis der PR mergebar ist und meldet erst dann zurück.
argument-hint: [issue-nummer-oder-url]
---

# EDP-Issue autonom lösen

Orchestrator vom GHE-Issue bis zum mergebaren PR. **Voll autonom** — meldet sich erst zurück, wenn der PR
theoretisch mergebar ist (oder ein echter Blocker eine Entscheidung von Tim braucht).

> **Dieser Skill hält nur den Ablauf, nicht die Fakten.** Jede Konvention, jeder Pfad, jedes Kommando lebt in
> seiner Single Source of Truth (Vault-Note, repo-eigene `docs/GIT.md`, bestehender `/edp-*`-Skill) und wird
> hier **nur verlinkt**, nie kopiert. Ändert sich eine SSoT, greift die Änderung automatisch. Beim Ausführen
> die verlinkte Quelle lesen und ihr folgen — nicht aus dem Gedächtnis raten. Prinzip: [[tim/feedback/dry-vault-no-duplication]].

## Voraussetzungen

- Env: `EDP_VM_HOST`, `EDP_PROJECT_ROOT` (Mac-Setup + Fallen: `$VAULT/referenz/edp-project-root-mac.md`)
- Tools: `gh`, `git`, `ssh`, `edp`, `playwright-cli`
- Projekt: lokales EDP-Repo-Checkout (Pfad-Muster laut `$VAULT/referenz/edp-project-root-mac.md`)

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Grundhaltung

- **Softwarehaus mit Reputation.** Qualität vor Tempo, langfristig statt kurzfristig geflickt. Erst melden,
  wenn wirklich alles verifiziert funktioniert — kein halbfertiges Produkt.
- **Nichts annehmen, alles verifizieren.** Keine Mutmaßungen über Repro, Ursache oder Wirkung des Fixes.
- **Expertenteam bilden.** Für domänentiefe Teilaufgaben (Reproduktion, Root-Cause, Implementierung,
  Verifikation, je Modul/Bereich) spezialisierte Subagents einsetzen, die selbst wieder delegieren dürfen —
  gemäß [[tim/feedback/experten-team-modell]]. Der Main-Agent koordiniert und hält die Übersicht.
- **Big Bang, keine Altlast** ([[tim/feedback/big-bang-statt-altlasten]]) — aber pre-existing public Surface bleibt.
- **`$VAULT`** = host-abhängiger Vault-Root (siehe CLAUDE.md). Vor nicht-trivialen Teilschritten die passende
  `$VAULT/tim/feedback/`-Note (INDEX.md) und repo-spezifische Notes unter `$VAULT/projekte/<repo>/` konsultieren.

## Schritt 1: Issue + gesamten Kontext erfassen

Aus `$ARGUMENTS` Repo und Issue-Nummer ableiten (URL-Muster `.../edp/<repo>/issues/<nr>` oder bloße Nummer +
aktuelles Repo). GHE-Host/`gh`-Aufruf-Quirks: `$VAULT/referenz/ghe-instance-quirks.md`.

**Was gebraucht wird** (Leseabfrage — beschaffen wie es am besten passt, gern per Subagent):

```json
{
  "repo": "edpweb",
  "issue": {"nummer": 369, "titel": "...", "body": "...", "labels": ["merge:bug"], "state": "open"},
  "verlinkungen": {
    "sub_issues": [370],
    "verlinkte_prs": [],
    "referenzierte_issues": [],
    "zammad_nummern": [7624766],
    "urls": ["https://..."]
  },
  "branch_cascade_sektion": "## Branch & Cascade ... (falls im Body vorhanden)"
}
```

- **Allen Verlinkungen folgen**, bis der Sachverhalt vollständig verstanden ist: verlinkte/Sub-Issues, PRs,
  externe URLs, und **jede erwähnte Zammad-Nummer** (`EDP#<nr>`) via `/zammad-read` (inkl. Kunden-Artikel,
  Screenshots, exakter Trigger-Beschreibung). Bei Bedarf Web-Quellen via `/defuddle`.
- **Nicht benötigt:** Kommentar-Rauschen ohne Sachbezug, geschlossene unverwandte Issues.

Ergebnis: präzises Verständnis von **was genau** passiert, **wo** (welcher Branch/Kunde/Stand) und **welcher
exakte Trigger/Pfad** gemeldet wurde ([[tim/feedback/fehler-reproduktion-exakter-pfad]]).

## Schritt 2: Klassifizieren — Bug oder Feature

Aus Issue + Kontext entscheiden. Bei Bug → Schritt 3. Bei Feature → Schritt 4. Im Zweifel wie ein Bug behandeln
(erst Ist-Verhalten reproduzieren/verstehen). Repo-Architektur zum Einordnen: `$VAULT/projekte/<repo>/architektur.md`.

## Schritt 3 (Bug): Reproduzieren, dann Ursache finden

**Ziel: Erst beweisen, dass der Bug real ist — automatisch durch dich —, dann die Quelle finden.**

**3a — Repro planen.** Vorhandenes Test-/Repro-Wissen zuerst nutzen (nicht neu erfinden):
- Backend deterministisch per HTTP-Form-POST: `$VAULT/referenz/edpweb-testing/index.md` (Hub → `setup`, `auth`,
  `snippets`, `actions-<bereich>`, `db-kerntabellen`).
- UI-Reproduktion/Verifikation: `/edp-design-loop` bzw. direkt `/playwright-cli` (Login/Cache-Fallen:
  [[tim/feedback/code-self-check-vor-review]]).
- DB-Read-Back: `/edp-database` + `$VAULT/referenz/edpweb-testing/db-kerntabellen.md`.
- Reproduktion auf Release-/Kundenstand zur Abgrenzung: `$VAULT/referenz/edpweb-demo-instanzen.md`;
  Testdaten/Lage: `$VAULT/referenz/edpweb-demo-lage-reset.md`.
- Repo-spezifische Notes unter `$VAULT/projekte/<repo>/` und `$VAULT/referenz/` (z.B. `delphi-live-debug-vm.md`).

**3b — Exakten gemeldeten Pfad nachstellen**, nicht einen benachbarten ([[tim/feedback/fehler-reproduktion-exakter-pfad]]).
Jeden gemeldeten Pfad einzeln. Gelieferte Logs/Traces gegen den getesteten Pfad gegenchecken.

**3c — Wenn du es nicht allein reproduzieren kannst:** kein Blindflug. Kurz an Tim eskalieren mit präziser
Bitte, den Schritt für dich zu testen (letzte Instanz). **Ziel bleibt aber Automatisierung** — siehe Schritt 7:
das dabei gewonnene Repro-Wissen ins Vault einpflegen, damit es beim nächsten Mal allein geht.

**3d — Root-Cause.** Code-Pfad vom Trigger bis zum Fehlerpunkt verfolgen, Fehlerquelle eindeutig lokalisieren.
Bei Concurrency-/Lock-Themen: [[tim/feedback/concurrency-fix-baseline-verify]]. Fix konzeptionell festlegen
(saubere End-Lösung, kein Flicken).

## Schritt 4 (Feature): Detailplanung

Feature-Anforderung vollständig gegen die bestehende Architektur planen: `$VAULT/projekte/<repo>/architektur.md`
und repo-eigene Doku. Integrationspunkte, Datenmodell, Schnittstellen-/Rechte-Auswirkungen, Edge-Cases festlegen.
Lösung so entwerfen, dass sie sich sauber in bestehenden Code fügt (kein Parallelkonzept, keine Altlast).

## Schritt 5: Branch + Cascade bestimmen, Fix umsetzen, Tests

**5a — Repo lokal + Branch/Cascade.** Repo-Checkout gemäß `$VAULT/referenz/edp-project-root-mac.md`. Den
**niedrigsten betroffenen Branch** (Fall A–D) und den Cascade-Pfad bestimmen — verbindlich aus der repo-eigenen
`docs/GIT.md`, ergänzt durch `$VAULT/referenz/edp-schnittstellen-branch-konvention.md`,
`$VAULT/projekte/edpweb/architektur.md` (Branching) und [[tim/feedback/issue-fix-branch-cascade-festhalten]].
Fix-Branch von der korrekten Basis anlegen (nie auf Default-Branch direkt committen).

**5b — Umsetzen.** Fix bzw. Feature implementieren. Datei-Encoding strikt beachten
([[tim/feedback/datei-encoding]], `$VAULT/referenz/edp-cascade-encoding-check.md`) — v.a. Win-1252 bei Delphi.
Echte Umlaute. Regelverstöße im berührten Code mitkorrigieren ([[tim/feedback/regelverstoesse-immer-korrigieren]]).

**5c — Tests mitwachsen lassen** ([[tim/feedback/tests-dynamisch-erweitern]], [[tim/feedback/delphi-tests-immer]]):
bei Bugs erst reproduzierender Test (rot), dann Fix (grün); Features → Happy-Path + Edge-Cases. Delphi = DUnitX
(`$VAULT/referenz/dunitx-patterns.md`, `$VAULT/projekte/edpweb/dunitx-test-harness-pickup.md`), Go = `go test`,
Frontend = Repo-Standard. Vor jedem Commit/Deploy die **gesamte Suite grün**. Build/Deploy nur via `/edp-develop`.

## Schritt 6: End-to-End verifizieren (Self-Check)

Vor jeder Rücklaufmeldung selbst beweisen, dass der Fix die Problematik löst bzw. das Feature alle
Gütekriterien erfüllt — **CI-grün genügt nicht** ([[tim/feedback/code-self-check-vor-review]]):

- Bug: den in Schritt 3 etablierten Repro erneut fahren → Fehler **weg**; Regressionsnachbarn stichprobenartig ok.
- Feature: Akzeptanzkriterien real durchspielen (Backend-POST + DB-Read-Back und/oder `/edp-design-loop` UI).
- Concurrency: unter echtem parallelem Szenario ([[tim/feedback/concurrency-fix-baseline-verify]]).
- Cascade-Bug (Fall C): prüfen, ob der Fix in **beiden** betroffenen Codebasen greift, falls das Repo pro
  Branch getrennte Renderer/Module hat (siehe `$VAULT/projekte/edpweb/architektur.md`).

Nicht bestanden → zurück zu Schritt 5 (bzw. 3d), iterieren bis sauber.

## Schritt 7: Wissen sichern + Issue/Doku aktuell halten

- **Neu gewonnenes Repro-/Test-Wissen** in die **passende bestehende** Vault-SSoT einpflegen (Endpunkt-Wissen →
  `$VAULT/referenz/edpweb-testing/` Hub-Konvention; Architektur/Repro-Ablauf → `$VAULT/projekte/<repo>/`),
  **niemals dupliziert**, konsistent mit vorhandenem Frontmatter/Verifiziert-Marker-Stil. Ziel: nächstes Mal
  mehr allein. (Vault-Writes werden per Hook autocommittet.)
- **Issue aktuell halten:** relevante Erkenntnisse (Root-Cause, ggf. `## Branch & Cascade`) am Issue ergänzen,
  wenn sie fehlen. Schreibaktionen auf GHE via `gh` (Host-Quirks: `$VAULT/referenz/ghe-instance-quirks.md`).

## Schritt 8: PR erstellen und bis zur Mergebarkeit treiben

**8a — PR** via `/edp-pull-request` (Titel/Body/Zammad-Notiz/Assignee `tim-rudorf`/Copilot-Reviewer per dessen
Konvention). Im **Autonomie-Modus** den Entwurf ohne Zwischenbestätigung erstellen. `Closes/Fixes #<nr>` je
vollständig erledigtem Issue in den Body ([[tim/feedback/pr-issues-auto-schliessen]]).

**8b — CI beobachten** ([[tim/feedback/ci-nach-push-beobachten]]): Run-Status abwarten; bei Fehlschlag Logs
ziehen, Ursache fixen (zurück zu Schritt 5, Suite grün halten), pushen, erneut prüfen.

**8c — Copilot-Review-Loop:** sobald das Review da ist, per `/edp-copilot-review` abarbeiten (umsetzen oder
begründet ablehnen, Threads beantworten + resolven; [[tim/feedback/vor-merge-reviews-pruefen]]). Nach jedem
Code-Push reviewt Copilot neu → erneut prüfen.

**8d — Loop bis mergebar** ([[tim/feedback/pr-fertig-erst-wenn-mergebar]]): `mergeStateStatus CLEAN` /
`mergeable MERGEABLE` als Definition of Done. Blocker (BLOCKED/BEHIND/DIRTY/roter Check) je Ursache auflösen,
bis merge-ready. Den eigentlichen Merge dem Team/Reviewer überlassen.

**8e — Report.** Erst jetzt an Tim zurückmelden: Issue, Root-Cause bzw. Feature-Lösung, Fix-Zusammenfassung,
Verifikations-Beleg, PR-URL + Mergebarkeits-Status. Kompakt, deutsch, echte Umlaute.

## Regeln

- **Autonom bis mergebar.** Nur unterbrechen, wenn ein echter Blocker eine Entscheidung von Tim braucht oder ein
  Repro-Schritt nur manuell durch Tim geht (Schritt 3c). Reine Reads/interne Systeme: einfach machen.
- **Kein Hardcode, kein Duplikat.** Fakten immer aus der verlinkten SSoT ziehen und ihr folgen.
- **Nach jeder externen Mutation Read-back** ([[tim/feedback/schreib-verify]]).
- **Kein Hinweis auf AI** in Issue/PR/Zammad/Reviews. Deutsch mit echten Umlauten.
- **Externer Kundenversand** (Zammad public) nur mit Freigabe und in Tims Duktus (CLAUDE.md).

Abschließend `skill-optimize` mit `edp-issue` aufrufen.

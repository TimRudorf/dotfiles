# Issue-Workflow — gemeinsamer Ablauf-Core

Host-agnostischer Ablauf vom Issue bis zum abgeschlossenen PR. Wird von den Profil-Skills
`edp-issue` (GHE/Arbeit) und `gh-issue` (github.com/Privat) gelesen — **nie direkt aufrufen**.

> **Der Core hält den Ablauf, das Profil hält die Fakten.** Jede Stelle, an der sich die Welten
> unterscheiden, ist unten als **Hook** `«NAME»` markiert. Der aufrufende Skill füllt in seiner
> `## Profil`-Sektion **jeden** Hook. Fehlt einer, nicht raten — im Profil nachlesen oder abbrechen.
> Fakten leben in ihrer SSoT (Vault-Note, repo-eigene Doku, anderer Skill) und werden nur verlinkt,
> nie kopiert ([[tim/feedback/dry-vault-no-duplication]]).

## Hook-Liste

| Hook | Was das Profil festlegt |
|---|---|
| `«HOST»` | Git-Host, `gh -R`-Muster, Host-Quirks |
| `«TICKET»` | vorgelagertes Ticket-System (oder „keins") |
| `«CHECKOUT»` | wo das Repo lokal liegt / wie es beschafft wird |
| `«STATUS-SIGNAL»` | wie „in Arbeit" am Issue signalisiert wird |
| `«BRANCH»` | Branch-Modell, Basis-Branch, Cascade-Regeln |
| `«ENCODING»` | Datei-Encoding-Regime |
| `«TESTS»` | Test-Framework + Kommando je Sprache |
| `«VERIFY»` | wo und womit end-to-end verifiziert wird |
| `«WISSEN»` | wohin neu gewonnenes Wissen gehört |
| `«PR»` | PR-Erstellung, Labels, Body-Konventionen |
| `«ABSCHLUSS»` | Merge-Policy + Definition of Done |
| `«TABUS»` | harte profil-spezifische Verbote |

## Grundhaltung

- **Qualität vor Tempo.** Erst melden, wenn alles verifiziert funktioniert — kein halbfertiges Produkt.
- **Nichts annehmen, alles verifizieren.** Keine Mutmaßungen über Repro, Ursache oder Wirkung des Fixes.
- **Expertenteam bilden.** Domänentiefe Teilaufgaben (Reproduktion, Root-Cause, Implementierung,
  Verifikation) an spezialisierte Subagents geben, die selbst delegieren dürfen
  ([[tim/feedback/experten-team-modell]]). Der Main-Agent koordiniert und hält die Übersicht.
- **Big Bang, keine Altlast** ([[tim/feedback/big-bang-statt-altlasten]]) — aber pre-existing public
  Surface (Endpoints, Telegramme, Routen) bleibt erhalten.
- **`$VAULT`** = host-abhängiger Vault-Root (siehe CLAUDE.md). Vor nicht-trivialen Teilschritten die
  passende `$VAULT/tim/feedback/`-Note (via `INDEX.md`) und `$VAULT/projekte/<repo>/` konsultieren.

## Schritt 1: Issue + gesamten Kontext erfassen

Aus `$ARGUMENTS` Repo und Issue-Nummer ableiten (URL, `<repo>#<nr>` oder bloße Nummer + aktuelles Repo)
gemäß `«HOST»`.

**Sofort `«STATUS-SIGNAL»` setzen**, sobald Repo + Nummer feststehen und die Bearbeitung beginnt.

**Was gebraucht wird** (Datenbeschaffung — Beschaffungsweg frei wählbar):

```json
{
  "repo": "<name>",
  "issue": {"nummer": 42, "titel": "...", "body": "...", "labels": ["bug"], "state": "open"},
  "verlinkungen": {
    "sub_issues": [], "verlinkte_prs": [], "referenzierte_issues": [],
    "externe_tickets": [], "urls": []
  }
}
```

- **Allen Verlinkungen folgen**, bis der Sachverhalt vollständig verstanden ist: verlinkte/Sub-Issues,
  PRs, externe URLs (bei Bedarf via `/defuddle`) und jedes externe Ticket gemäß `«TICKET»`.
- **Nicht benötigt:** Kommentar-Rauschen ohne Sachbezug, geschlossene unverwandte Issues.

Ergebnis: präzises Verständnis von **was genau** passiert, **wo** (Branch/Umgebung/Stand) und **welcher
exakte Trigger/Pfad** gemeldet wurde ([[tim/feedback/fehler-reproduktion-exakter-pfad]]).

## Schritt 2: Klassifizieren — Bug oder Feature

Bug → Schritt 3. Feature → Schritt 4. Im Zweifel wie einen Bug behandeln (erst Ist-Verhalten verstehen).
Repo-Architektur zum Einordnen: `$VAULT/projekte/<repo>/architektur.md`, sonst repo-eigene Doku.

## Schritt 3 (Bug): Reproduzieren, dann Ursache finden

**Ziel: Erst beweisen, dass der Bug real ist — automatisch durch dich —, dann die Quelle finden.**

**3a — Repro planen.** Reproduktion läuft in der Umgebung aus `«VERIFY»`. Vorhandenes Repro-/Test-Wissen
zuerst nutzen statt neu erfinden (Quellen laut `«VERIFY»` und `«WISSEN»`).

**3b — Exakten gemeldeten Pfad nachstellen**, nicht einen benachbarten
([[tim/feedback/fehler-reproduktion-exakter-pfad]]). Jeden gemeldeten Pfad einzeln. Gelieferte
Logs/Traces gegen den tatsächlich getesteten Pfad gegenchecken.

**3c — Wenn du es nicht allein reproduzieren kannst:** kein Blindflug. Kurz an Tim eskalieren mit
präziser Bitte, den Schritt zu testen (letzte Instanz). Ziel bleibt Automatisierung — das dabei
gewonnene Wissen in Schritt 7 sichern, damit es beim nächsten Mal allein geht.

**3d — Root-Cause.** Code-Pfad vom Trigger bis zum Fehlerpunkt verfolgen, Fehlerquelle eindeutig
lokalisieren. Bei Concurrency-/Lock-Themen: [[tim/feedback/concurrency-fix-baseline-verify]]. Fix
konzeptionell festlegen (saubere End-Lösung, kein Flicken).

## Schritt 4 (Feature): Detailplanung

Anforderung vollständig gegen die bestehende Architektur planen: Integrationspunkte, Datenmodell,
Schnittstellen-/Rechte-Auswirkungen, Edge-Cases. Lösung so entwerfen, dass sie sich in bestehenden Code
fügt — kein Parallelkonzept, keine Altlast. Berührt das Issue eine Oberfläche, gilt zusätzlich die im
Profil benannte Design-Vorgabe.

## Schritt 5: Branch bestimmen, umsetzen, Tests

**5a — Repo lokal + Branch.** Checkout gemäß `«CHECKOUT»`, Branch-Wahl gemäß `«BRANCH»`. Nie direkt auf
dem Basis-/Default-Branch committen.

**5b — Umsetzen.** Datei-Encoding strikt nach `«ENCODING»`, echte Umlaute. Auffallende Regelverstöße im
berührten Code mitkorrigieren ([[tim/feedback/regelverstoesse-immer-korrigieren]]).

**5c — Tests mitwachsen lassen** ([[tim/feedback/tests-dynamisch-erweitern]]): bei Bugs **erst** ein
reproduzierender Test (rot), **dann** der Fix (grün); Features → Happy-Path + Edge-Cases. Framework und
Kommando laut `«TESTS»`. Vor jedem Commit/Deploy die **gesamte Suite grün**.

## Schritt 6: End-to-End verifizieren (Self-Check)

Vor jeder Rückmeldung selbst beweisen, dass der Fix die Problematik löst bzw. das Feature seine
Gütekriterien erfüllt. **CI-grün genügt nicht** ([[tim/feedback/code-self-check-vor-review]]) — verifiziert
wird gegen einen real laufenden Stand gemäß `«VERIFY»`.

- Bug: den in Schritt 3 etablierten Repro erneut fahren → Fehler **weg**; Regressionsnachbarn stichprobenartig ok.
- Feature: Akzeptanzkriterien real durchspielen.
- Concurrency: unter echtem parallelem Szenario ([[tim/feedback/concurrency-fix-baseline-verify]]).

Geht die Verifikation technisch nicht (Umgebung down, Deploy scheitert) → transparent melden, **nicht**
mit einer schwächeren Ersatzprüfung kaschieren. Nicht bestanden → zurück zu Schritt 5 (bzw. 3d), iterieren.

## Schritt 7: Wissen sichern + Issue aktuell halten

- **Neu gewonnenes Repro-/Test-/Architektur-Wissen** in die passende **bestehende** SSoT einpflegen
  (Ziel laut `«WISSEN»`), niemals dupliziert, im vorhandenen Frontmatter-/Stil-Kanon. Ziel: nächstes Mal
  mehr allein schaffen.
- **Issue aktuell halten:** fehlende relevante Erkenntnisse (Root-Cause, Branch-Entscheidung) am Issue
  ergänzen.

## Schritt 8: PR erstellen und bis zum Abschluss treiben

**8a — PR** gemäß `«PR»` erstellen. Im Autonomie-Modus ohne Zwischenbestätigung.
`Closes/Fixes #<nr>` je vollständig erledigtem Issue in den Body, nur teilweise Bezüge als `Ref #<nr>`
([[tim/feedback/pr-issues-auto-schliessen]]).

**8b — CI beobachten** ([[tim/feedback/ci-nach-push-beobachten]]): Run-Status abwarten; bei Fehlschlag Logs
ziehen, Ursache fixen (zurück zu Schritt 5, Suite grün halten), pushen, erneut prüfen.

**8c — Lokales Review:** per `/edp-review` einen skeptischen Review-Agent auf den Diff ansetzen, dessen
Funde selbst verifizieren und die berechtigten fixen ([[tim/feedback/pr-review-lokaler-agent]],
[[tim/feedback/vor-merge-reviews-pruefen]]). Nach jedem Fix-Push CI erneut abwarten.

**8d — Loop bis mergebar** ([[tim/feedback/pr-fertig-erst-wenn-mergebar]]): `mergeStateStatus CLEAN` /
`mergeable MERGEABLE` als Mindestzustand. Blocker (BLOCKED/BEHIND/DIRTY/roter Check) je Ursache auflösen.
Was danach passiert, regelt `«ABSCHLUSS»`.

**8e — Report.** Erst jetzt an Tim: Issue, Root-Cause bzw. Feature-Lösung, Fix-Zusammenfassung,
Verifikations-Beleg, PR-URL + Status. Kompakt, deutsch, echte Umlaute
([[tim/feedback/doku-kurz-und-verstaendlich]]).

## Regeln

- **Autonom bis zum Abschluss.** Nur unterbrechen, wenn ein echter Blocker eine Entscheidung von Tim
  braucht oder ein Repro-Schritt nur manuell geht (3c). Reine Reads/interne Systeme: einfach machen.
- **Kein Hardcode, kein Duplikat.** Fakten aus der verlinkten SSoT ziehen und ihr folgen, nicht aus dem
  Gedächtnis raten.
- **Nach jeder externen Mutation Read-back** ([[tim/feedback/schreib-verify]]).
- **Kein Hinweis auf AI** in Issue/PR/Reviews. Deutsch mit echten Umlauten.
- Zusätzlich gilt alles unter `«TABUS»`.

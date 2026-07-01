---
name: anki
description: User invokes /anki for spaced-repetition card workflow with Anki Desktop. Four sub-commands - `build <le-slug>` (STANDARD since 2026-07-01) builds the pre-written, klausur-kalibrierten Gold-Standard card plan from a Lerneinheit's '🎴 Anki-Karten-Plan' section into Anki — plans live IN the LE, Tim triggers the build AFTER working through that LE (never pre-build; see [[tim/feedback/anki-erst-nach-le-durchgearbeitet]]); `cards <modul>` for ad-hoc/legacy interactive card creation (Tim sends source material like screenshot/text/PDF excerpt, Jarvis proposes Cloze/Basic cards atomically with MathJax, Tim approves/edits/rejects, accepted cards go via AnkiConnect into Uni::<Module> deck with source+phase tags); `status [--modul=<slug>]` for snapshot of due/retention per module deck written to vault; `setup` for one-time deck initialization. Big-Bang: no FB18-imports, no inbox-decks, direct write after approval. Phase 4 blocks new cards (klausur-hygiene). Trigger keywords - anki, karte, karteikarte, /anki, "erstelle die karten für LE", anki build, anki status, "neue anki karten", "wieviel due", spaced repetition, cloze.
disable-model-invocation: true
argument-hint: <build|cards|status|setup> [le-slug|modul-slug]
---

# Anki — Karten + Lernfortschritt

Spaced-Repetition-Workflow mit Anki Desktop am Mac. Karten werden interaktiv im Chat erstellt (Tim nimmt jede Karte ab, Generation Effect ist Teil des Lernens), Stats werden als Snapshot ins Vault geschrieben für die Druck-Score-Berechnung im Heartbeat.

Vollkonzept: `$VAULT/projekte/lernplan/anki-konzept.md`. Recherche-Grundlage: `$VAULT/sources/2026-05-08-anki-integration.md`.

## Voraussetzungen

- Tools: `curl`, `jq`
- Datei: `~/Documents/jarvis-wiki/projekte/lernplan/anki-konzept.md`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Schritt 1: AnkiConnect-Erreichbarkeit prüfen

`bash scripts/check_ankiconnect.sh` ausführen. Output bei Erfolg: `OK`. Bei Fehler: stoppen mit Meldung *"Mac-Anki nicht erreichbar — bitte Anki Desktop am Mac öffnen."* Kein Retry.

## Schritt 2: Sub-Command routen

Argument 1 ist der Sub-Command (`cards`, `status`, `setup`). Bei unbekanntem oder fehlendem Sub-Command: knappe Usage anzeigen und stoppen.

## Sub-Command: `build <le-slug>` — Karten aus dem LE-Plan bauen (STANDARD seit 2026-07-01)

**Modell (IntEco-Pilot, künftig alle Module):** Die Karten-Pläne stehen **fertig im „🎴 Anki-Karten-Plan"-Bereich jeder LE** — lean, klausur-kalibriert, gegen das Content-PDF verifiziert (Gold-Standard, siehe [[projekte/lernplan/anki-kartendesign]]). Tim arbeitet die LE durch und **triggert dann den Bau** („erstelle die Karten für LE X"). Kein interaktives Vorschlagen mehr — der Plan IST die Vorlage; nur Feinschliff passiert beim Bau. **Nie vorab bauen** ([[tim/feedback/anki-erst-nach-le-durchgearbeitet]]).

Ablauf:

1. **LE lokalisieren:** `<le-slug>` → `$VAULT/projekte/lernplan/<modul>/lerneinheiten/<le-slug>.md` (Modul aus Slug-Präfix, z.B. `iti-*`/`imf-*` → `international-economics`; sonst explizit).
2. **Durcharbeitungs-Check:** Lernablauf-Checkboxen der LE lesen — „Lernzettel-lesen"/„Mini-Essay" ✅? Wenn klar noch nicht durchgearbeitet → knapp rückfragen statt bauen (Regel: erst nach Durcharbeiten).
3. **Plan parsen:** die nummerierten Karten im „🎴 Anki-Karten-Plan"-Block lesen:
   - **Cloze** / **Overlapping Cloze** → Notetype `Cloze`, Feld `Text` = Content inkl. `{{cN::…}}`. Overlapping = **ein** Note mit mehreren `cN` (Sibling-Burying zeigt pro Review ein Blank — nicht in Einzelnotes splitten).
   - **Basic** → Notetype `Basic`, `Front`/`Back`.
   - **Image Occlusion 🖼️** → NICHT über `add_cards.sh`; via `python3 $VAULT/projekte/lernplan/anki-io-build.py` bauen (Skizze aus Content-PDF/Folie rendern → Masken → Pillow-Self-Check → `addNote` Modell „Image Occlusion"). Skizze-Quelle + Masken-Hinweis stehen in der Karte.
4. **Dedup-Guard:** existieren schon Karten mit `tag:source::<modul>::<le-slug>`? Wenn ja (Re-Build) → erst archivieren + löschen, dann neu bauen (idempotent). Bei leerem/neuem Stand einfach neu.
5. **Bauen (aktiv):** Karten-JSON zusammenstellen, `bash scripts/add_cards.sh Uni::<Modul> <karten.json>`. Tags **`phase::<aktive-phase>` + `source::<modul>::<le-slug>`**. Karten gehen **aktiv** ins Deck (nicht suspendiert) — Tim kennt den Stoff jetzt. `add_cards.sh` ruft am Ende `anki-deck-config.py` (kein Default-Preset).
6. **IO-Karten** separat via `anki-io-build.py` (gleiche Tags + Deck).
7. **Verify (`schreib-verify`):** pre/post AnkiWeb-Sync; Read-back `findNotes`/`findCards` per `source::`-Tag gegen Plan-Soll.
8. **LE + Tracker nachziehen:** Lernablauf-Checkbox „Karten-erstellen" ✅ + Datum, Sessions-Block, Frontmatter (`karten-notes`/`karten-ist`), Tracker-Zeile (🔄-Ampel + Karten-Count).

> [!tip] Feinschliff beim Bau
> Der Plan ist ein geprüfter Vorschlag, kein Dogma. Fällt beim Bauen eine offensichtlich zu tiefe/überzählige Karte auf (Trivia, das nie in einer 5-Sätze-5-P-Antwort landet) → kurz mit Tim abstimmen und straffen (Lean-Prinzip). Bekanntes Beispiel: `imf-08-sanctions` ist am schwersten (Karten 12–14 grenzwertig).

## Sub-Command: `cards <modul-slug> [kapitel-hinweis...]` — Ad-hoc / Legacy

> Für spontane Einzelkarten außerhalb des LE-Plan-Modells (anderes Modul, Lücken-Karte aus einem Fehler). Für IntEco + alle Module mit fertigem LE-Karten-Plan gilt `build <le-slug>`.

### 2.1 Modul validieren

`<modul-slug>` muss einer der 12 Slugs sein (Mapping unten). Bei Fehler: Liste anzeigen und stoppen.

### 2.2 Fokus-Modus + Klausur-Hygiene prüfen

> Es gibt seit der LE-Migration (Big-Bang 2026-05-13) **kein `plan.md`/`phasen:`** mehr — Module laufen datumslos über `modul.md` + `tracker.md` + `lerneinheiten/`.

1. **Fokus-Modus:** Wenn `$VAULT/projekte/lernplan/fokus-business-klausuren-2026-07.md` (bzw. eine `fokus-*`-Note mit `status: aktiv` und `gilt_bis` in der Zukunft) existiert, dürfen nur die dort gelisteten Module bekartet werden. Anderes Modul → Warnung *"Modul X ist im Fokus-Modus pausiert (bis <gilt_bis>). Mit `--force` überschreibbar."*, stoppen außer `--force`.
2. **Klausur-Hygiene:** `klausur`-Datum aus `<modul-slug>/modul.md` lesen. Wenn die Klausur **≤ 2 Tage** entfernt ist → Warnung *"Klausur in <n> Tagen — keine neuen Karten mehr (Hygiene). Mit `--force` überschreibbar."*, stoppen außer `--force`.

### 2.3 Modul-Kontext laden

`$VAULT/projekte/lernplan/<modul-slug>/modul.md` lesen für Frontmatter — vor allem `klausur.sprache` (DE oder EN), `anki_rolle`, `modul_typ`. Karten-Vorschläge in der Modul-Sprache formulieren.

### 2.4 Karten-Format-Regeln (aus anki-konzept.md)

- **Atomic** — eine Karte = ein Fakt. "Und"/Komma in der Antwort → splitten.
- **Cloze primär für STEM** (`{{c1::antwort}}`), Basic für Q/A.
- **MathJax außerhalb von Cloze**: `Was ist {{c1::die Lösung der DARE}}? \[P = A^T P A - A^T P B (R + B^T P B)^{-1} B^T P A + Q\]` ist OK. Cloze-Marker dürfen **nicht** mitten in eine Formel.
- **Eigene Worte** — verbatim-Klausurformeln OK, verbatim-Definitionen aus Skript meistens nicht.
- **Nie ambig** — wenn die Antwort eine von vielen sein könnte, ist die Frage falsch.
- **3–8 Karten pro Auszug** — nicht überfluten.

### 2.5 Stoff-Auszug einsammeln

Tim wird gebeten, einen Stoff-Auszug zu schicken: Screenshot, Text-Auszug, PDF-Auszug, oder Verweis auf eine Datei. Der Kapitel-Hinweis aus dem Aufruf (Argumente nach dem Slug) geht in den Source-Tag.

### 2.6 Karten-Vorschläge generieren

Für den Auszug 3–8 Karten als nummerierte Liste vorschlagen. Format pro Karte:

```
[1] Cloze — source::<modul>::<kapitel-slug>
Front: Was ist {{c1::die Lösung der DARE}}?
Extra: \[P = A^T P A - A^T P B (R + B^T P B)^{-1} B^T P A + Q\]

[2] Basic — source::<modul>::<kapitel-slug>
Front: ...
Back: ...
```

### 2.7 Iterativ verfeinern

Tim antwortet mit *"ja"* / *"Karte 2 anders: ..."* / *"Karte 4 raus"* / *"noch eine zu X"*. Iterieren bis Tim *"fertig"* oder *"alle ok"* sagt.

### 2.8 Karten ins Deck schreiben

Akzeptierte Karten als JSON-Datei zusammenstellen, dann `bash scripts/add_cards.sh <deck-name> <karten.json>` aufrufen. Format der Karten-JSON:

```json
[
  {
    "modelName": "Cloze",
    "fields": {"Text": "Was ist {{c1::die Lösung der DARE}}? \\[P = ...\\]", "Back Extra": ""},
    "tags": ["source::mpc-ml::kap-iv-lqr", "phase::1"]
  },
  {
    "modelName": "Basic",
    "fields": {"Front": "Wie viele Stabilitätsbedingungen hat MPC?", "Back": "Vier — Terminal Region forward invariant + Terminal Controller satisfies input constraints + Terminal Controller stabilizes inside terminal region + Stage Cost positive definite."},
    "tags": ["source::mpc-ml::kap-v-mpc", "phase::1"]
  }
]
```

`add_cards.sh` legt das Deck an (idempotent), schreibt die Karten via `addNotes`, prüft Duplikate (allowDuplicate=false) und ruft danach automatisch das **Deck-Config-Normalize-Skript** (`$VAULT/projekte/lernplan/anki-deck-config.py`) auf — damit das (ggf. neu angelegte) Deck nicht auf „Default" (20/Tag) hängenbleibt, sondern das Modul-Preset erbt. Pattern: [[tim/feedback/anki-deck-config-pattern]].

### 2.9 Bestätigung

Bei Erfolg: *"N Karten in `Uni::<Modul>` angelegt. iPhone-Sync passiert beim nächsten Anki-Sync (cmd+Y am Mac, oder automatisch beim Beenden)."*

## Sub-Command: `status [--modul=<slug>]`

`bash scripts/snapshot.sh [<modul-slug>]` aufrufen. Das Skript zieht via AnkiConnect für jedes der 12 Modul-Decks (oder nur das angegebene): `total`, `due_today`, `due_week`, `mature_pct`, `young_count`, `new_count`, `lapses_total`. Schreibt Snapshot nach `$VAULT/projekte/lernplan/anki-stats.md` mit Frontmatter (`type: projekt`, `last_snapshot: <ISO-Timestamp>`).

Auto-Commit-Hook im Vault pusht das automatisch.

Nach erfolgreichem Snapshot kurz zusammenfassen: Top-3 Module mit den meisten `due_today`, plus alle Module mit `lapses_total > 5` der letzten Snapshot-Periode (wenn Vorperioden-Snapshot vorhanden).

**FSRS true_retention**: AnkiConnect liefert das nicht direkt. Approximation aus `cardsInfo`-Feld `lapses` und `reps` ist ungenau. Genauer: FSRS Helper Add-on hat einen "True Retention" Stats-Tab in Anki Desktop — wenn nötig, kann Tim die Zahl manuell aus Anki ablesen und in der Snapshot-Note ergänzen. Skript markiert `true_retention_30d: null` wenn nicht ermittelbar.

## Sub-Command: `setup`

`bash scripts/setup_decks.sh` aufrufen. Legt alle 12 Modul-Decks via `createDeck` an (idempotent — bestehende Decks werden nicht angefasst). Output: *"12 Decks bereit."*

## Modul-Slug → Anki-Deck Mapping

| Slug | Deck |
|---|---|
| `dimm` | `Uni::DIMM` |
| `ppm-seminar` | `Uni::PPM-Seminar` |
| `entrepreneurial` | `Uni::Entrepreneurial` |
| `modern-firm` | `Uni::Modern-Firm` |
| `international-economics` | `Uni::International-Economics` (kanonisch seit Schema-Migration 2026-06-29; das frühere `Uni::IntEco` + IMF-Subdecks wurden flachgezogen und gelöscht) |
| `rvcps` | `Uni::RVCPS` |
| `mldl-auto` | `Uni::ML-DL-Auto` |
| `praktikum-rt2` | `Uni::Praktikum-RT2` |
| `sdrt3` | `Uni::SDRT3` |
| `sensortechnik` | `Uni::Sensortechnik` |
| `thermo` | `Uni::Thermo` |
| `mpc-ml` | `Uni::MPC-ML` |

Mapping ist auch in `scripts/anki_call.sh` als Bash-Funktion `slug_to_deck` hinterlegt.

> [!important] Einheitliches Schema: flach pro Modul, KEINE Subdecks (seit 2026-06-29)
> Jedes Modul ist **genau ein flaches Deck** `Uni::<Modul>`. **Nie ein Kapitel-/VO-/LE-Subdeck anlegen** — Kapitel/VO/Übung leben ausschließlich im `source::<modul>::<kapitel>`-Tag (+ `phase::<n>`). Kapitel-Cramming pre-Klausur = temporäres Filtered Deck (`deck:Uni::<Modul> tag:source::*::<kapitel>*`). Falls ein LE-Karten-Plan einen Subdeck-Namen nennt (`Uni::SDRT3::Ü3`, `Uni::Sensortechnik::VO07`, `Uni::Entrep::ef-01`, …) → ignorieren, flach ins Modul-Deck schreiben. Schema + Why: [[projekte/lernplan/anki-schema-migration]] · [[tim/feedback/anki-karten-deck-kanonisch]].

## Stolperfallen

- **Anki Desktop muss offen sein** — AnkiConnect lauscht nur dann auf 8765. Wenn der Mac aus ist oder Anki nicht läuft: Skill bricht ab, kein Retry.
- **Cloze-Marker nicht in Formeln**: `\[{{c1::P = A^T P A...}}\]` bricht den MathJax-Parser. Stattdessen: `Was ist {{c1::die Lösung der DARE}}? \[P = A^T P A...\]` — Cloze drumherum, Formel sichtbar.
- **Sync-Race vor Bulk-Inserts**: Bei vielen Karten gleichzeitig vorher in Anki cmd+Y drücken (Sync mit AnkiWeb), dann Karten via Skill schreiben, dann nochmal syncen. Sonst kann ein Full-Sync vom iPhone die neuen Karten verlieren.
- **Phase-4-Override nur bewusst**: `--force` überspringt den Phase-4-Block — sollte selten gebraucht werden, weil keine-neuen-Karten-vor-Klausur ein Lerngesetz ist.
- **AnkiConnect Add-on Code**: `2055492159`. Repo seit 2025-11 nicht mehr auf GitHub-FooSoft, sondern `git.sr.ht/~foosoft/anki-connect` — Add-on-Code bleibt aber identisch.
- **FSRS-Re-Optimization**: alle 1–2 Monate manuell `Tools → FSRS Helper → Optimize FSRS parameters` in Anki Desktop ausführen, sonst hängen die Parameter.
- **Snapshot-Alter**: wenn `anki-stats.md` älter als 36 h ist, gibt der Heartbeat eine Notification raus. Tim soll dann kurz Anki Desktop öffnen und `/anki status` triggern.
- **Deck-Config / new-cards-Limit**: jedes flache Modul-Deck braucht sein eigenes Preset, **kein Uni-Deck auf „Default" (20/Tag)**. `add_cards.sh` ruft deshalb am Ende `anki-deck-config.py` auf. Wenn Karten **anders als über `add_cards.sh`** gebaut werden (z.B. `anki-io-build.py`, manueller `addNotes`), danach **manuell** `python3 $VAULT/projekte/lernplan/anki-deck-config.py` laufen lassen. Pattern + Why: [[tim/feedback/anki-deck-config-pattern]]. Bug-Präzedenz 2026-06-29 (strukturell gelöst durch die Flach-Migration): IntEco-Karten lagen in `IMF::*`-Subdecks auf Default → trotz 120er-Preset auf dem Top-Deck bei 20/Tag gedeckelt; seit der Migration gibt es keine Subdecks mehr, die auf Default zurückfallen könnten.

Abschließend `skill-optimize` mit `anki` aufrufen.

---
name: anki
description: User invokes /anki for spaced-repetition card workflow with Anki Desktop. Three sub-commands - `cards <modul>` for interactive card creation (Tim sends source material like screenshot/text/PDF excerpt, Jarvis proposes Cloze/Basic cards atomically with MathJax, Tim approves/edits/rejects, accepted cards go via AnkiConnect into Uni::<Module> deck with source+phase tags); `status [--modul=<slug>]` for snapshot of due/retention per module deck written to vault; `setup` for one-time deck initialization. Big-Bang: no FB18-imports, no inbox-decks, direct write after approval. Phase 4 blocks new cards (klausur-hygiene). Trigger keywords - anki, karte, karteikarte, /anki, anki status, "neue anki karten", "wieviel due", spaced repetition, cloze.
disable-model-invocation: true
argument-hint: <cards|status|setup> [modul-slug]
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

## Sub-Command: `cards <modul-slug> [kapitel-hinweis...]`

### 2.1 Modul validieren

`<modul-slug>` muss einer der 12 Slugs sein (Mapping unten). Bei Fehler: Liste anzeigen und stoppen.

### 2.2 Phase auslesen

Aus `$VAULT/projekte/lernplan/<modul-slug>/plan.md` Frontmatter `phasen:` die Phase mit `status: aktiv` finden → `aktive_phase_id`.

**Wenn `aktive_phase_id == 4`**: blockt mit Warnung *"Phase 4 = Klausur-Hygiene, keine neuen Karten. Mit `--force` überschreibbar."* User muss explizit `--force` angeben.

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

`add_cards.sh` legt das Deck an (idempotent), schreibt die Karten via `addNotes`, prüft Duplikate (allowDuplicate=false).

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
| `international-economics` | `Uni::International-Economics` |
| `rvcps` | `Uni::RVCPS` |
| `mldl-auto` | `Uni::ML-DL-Auto` |
| `praktikum-rt2` | `Uni::Praktikum-RT2` |
| `sdrt3` | `Uni::SDRT3` |
| `sensortechnik` | `Uni::Sensortechnik` |
| `thermo` | `Uni::Thermo` |
| `mpc-ml` | `Uni::MPC-ML` |

Mapping ist auch in `scripts/anki_call.sh` als Bash-Funktion `slug_to_deck` hinterlegt.

## Stolperfallen

- **Anki Desktop muss offen sein** — AnkiConnect lauscht nur dann auf 8765. Wenn der Mac aus ist oder Anki nicht läuft: Skill bricht ab, kein Retry.
- **Cloze-Marker nicht in Formeln**: `\[{{c1::P = A^T P A...}}\]` bricht den MathJax-Parser. Stattdessen: `Was ist {{c1::die Lösung der DARE}}? \[P = A^T P A...\]` — Cloze drumherum, Formel sichtbar.
- **Sync-Race vor Bulk-Inserts**: Bei vielen Karten gleichzeitig vorher in Anki cmd+Y drücken (Sync mit AnkiWeb), dann Karten via Skill schreiben, dann nochmal syncen. Sonst kann ein Full-Sync vom iPhone die neuen Karten verlieren.
- **Phase-4-Override nur bewusst**: `--force` überspringt den Phase-4-Block — sollte selten gebraucht werden, weil keine-neuen-Karten-vor-Klausur ein Lerngesetz ist.
- **AnkiConnect Add-on Code**: `2055492159`. Repo seit 2025-11 nicht mehr auf GitHub-FooSoft, sondern `git.sr.ht/~foosoft/anki-connect` — Add-on-Code bleibt aber identisch.
- **FSRS-Re-Optimization**: alle 1–2 Monate manuell `Tools → FSRS Helper → Optimize FSRS parameters` in Anki Desktop ausführen, sonst hängen die Parameter.
- **Snapshot-Alter**: wenn `anki-stats.md` älter als 36 h ist, gibt der Heartbeat eine Notification raus. Tim soll dann kurz Anki Desktop öffnen und `/anki status` triggern.

Abschließend `skill-optimize` mit `anki` aufrufen.

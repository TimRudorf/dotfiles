---
name: lerneinheit
description: User invokes /lerneinheit to generate a structured "Lerneinheit-Brief" before starting a study session. The brief is a Vault-Note under projekte/lernplan/<modul>/lerneinheiten/<YYYY-MM-DD>-<thema-slug>.md with concrete Lernziele, hardware-specific Material-Liste (reMarkable/Mac/Buch), Block-Plan (Pre-Read/Active-Read/Skizze/Self-Test), Self-Test-Fragen, Karten-Themen-Vorschläge for /anki, Crossovers to other modules, and "after the session" checkboxes (Verständnis-Score, Lücken). Pulls modul-specific context from modul.md (anki_rolle, modul_typ, klausur-format, klausur.sprache) and plan.md (aktive Phase + matching Pool-Item). Final step patches the corresponding Todoist task description with an Obsidian-URL deeplink to the new note. Trigger keywords - lerneinheit, brief, /lerneinheit, "ich fang gleich an mit", "lass mich auf X vorbereiten", "was soll ich heute machen für".
disable-model-invocation: true
argument-hint: <modul-slug> <thema-slug> [--minuten=N] [--datum=YYYY-MM-DD]
---

# Lerneinheit — Strukturierter Brief vor der Session

Generiert pro Lerneinheit eine Vault-Note mit konkretem Plan, Self-Test-Fragen und Karten-Themen-Vorschlägen für `/anki`. Verbindet den Brief mit dem passenden Todoist-Task (Vault-Link in der Description als Obsidian-URL).

Konzept-Kontext: [[projekte/lernplan/methodik]], [[projekte/lernplan/anki-konzept]]. Nicht zu verwechseln mit `/anki cards <modul>` — der Brief steht *vor* der Session, die Karten *während/nach* der Session.

## Voraussetzungen

- Tools: `curl`, `jq`, `python3`
- Datei: `~/Documents/jarvis-wiki/projekte/lernplan/methodik.md`
- Datei: `~/Documents/jarvis-wiki/projekte/lernplan/anki-konzept.md`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Schritt 1: Argumente parsen

Erwartet: `<modul-slug> <thema-slug> [--minuten=N] [--datum=YYYY-MM-DD]`.

- `modul-slug`: einer der 12 Slugs (siehe Mapping unten). Bei Fehler: Liste zeigen, stoppen.
- `thema-slug`: kebab-case Slug für Datei-Name + Anker (z. B. `vo01-messkette`, `kap-2-1-trajektorien`, `paper-3-meta-analyse`).
- `--minuten=N`: optional, default 75 wenn nicht im Pool-Item findbar.
- `--datum=YYYY-MM-DD`: optional, default `date +%Y-%m-%d` am Mac.

## Schritt 2: Modul-Kontext laden

Aus `~/Documents/jarvis-wiki/projekte/lernplan/<modul-slug>/modul.md` Frontmatter extrahieren:

- `klausur.sprache` (DE/EN) — Brief in dieser Sprache verfassen.
- `klausur.format`, `klausur.dauer_min`, `klausur.hilfsmittel`, `klausur.nicht_erlaubt` — wichtige Constraints für die Klausur-Realität-Sektion im Brief.
- `anki_rolle` (`primaer`/`struktur`/`konzept`/`marginal`) — bestimmt die Anki-Empfehlung im Brief.
- `modul_typ` (`konzeptuell`/`quantitativ`/`mixed`) — bestimmt, welche Lernmethoden im Block-Plan auftauchen (Worked Examples bei quantitativ, Concept Maps bei konzeptuell, vgl. [[projekte/lernplan/methodik]]).

Aus `~/Documents/jarvis-wiki/projekte/lernplan/<modul-slug>/plan.md`:

- Aktive Phase: das `phasen:`-Element mit `status: aktiv`. Phase-Nummer + Name + Deadline merken.
- **Pool-Item-Match**: in der aktiven Phase nach einem Pool-Item suchen, das zum `thema-slug` passt (Heuristik: VO/Kap-Nummer oder Stichwort im Item-Text). Bei mehreren Treffern: den mit höchstem Token-Overlap nehmen. Bei keinem Treffer: warnen aber fortfahren ("kein Pool-Item gefunden — Brief wird trotzdem erstellt, prüfe `thema-slug`").

**Wenn `aktive_phase_id == 4`**: warnen *"Phase 4 = Klausur-Hygiene, normalerweise nur Reviews, keine neuen Lerneinheiten. Mit `--force` erzwingbar."* — User muss `--force` setzen.

## Schritt 3: Brief-Inhalt generieren

Nach Template unten. Die **modul-spezifischen Felder** (Lernziele, Self-Test-Fragen, Karten-Themen, Crossovers) müssen aus dem Modul-Kontext + dem konkreten Thema abgeleitet werden — nicht generisch befüllt.

### Template-Struktur

```markdown
---
title: <MODUL-KÜRZEL> <THEMA-TITEL>
type: lerneinheit
tags: [uni, <modul-slug>, lerneinheit]
modul: <modul-slug>
thema_slug: <thema-slug>
datum: <YYYY-MM-DD>
phase: <N>
geplante_minuten: <N>
status: aktiv
---

> [!info] Kontext
> **Modul:** [[projekte/lernplan/<modul-slug>/modul]] · **Plan:** [[projekte/lernplan/<modul-slug>/plan]]
> **Phase <N>** (<Phasen-Name>) bis <deadline> · **Klausur-Format:** <kompakter Format-Hinweis aus modul.md>
> `anki_rolle: <rolle>` → <Floor-Slot-Hinweis aus cross-modul.md>

## 🎯 Lernziele

3–5 konkrete, prüfbare Outcomes. Nicht "verstehen", sondern "kann X benennen + erklären", "skizziert Y aus dem Kopf", "wendet Formel Z auf gegebenes Beispiel an".

## 📚 Material

Tabelle: Wo (reMarkable/Mac/Buch) — Was — Quelle. Pro Modul ableiten aus modul.md "Material"-Sektion + thema-passender Auswahl. iPhone nur erwähnen wenn Anki-Review explizit Teil dieser Einheit ist.

## 🧭 Vorgeschlagener Ablauf (<minuten> min)

Tabelle Block / Zeit / Tätigkeit / Gerät. Block-Aufbau modul-typ-abhängig:

- **konzeptuell**: Pre-Read → Active Read mit Elaborative Interrogation → Concept Map / Self-Explanation → Self-Test
- **quantitativ**: Pre-Read → Worked Examples studieren mit Self-Explanation → Eigene Aufgaben mit Hinweisen → Self-Test
- **mixed**: Mischung je nach Thema-Charakter

Für Sensortechnik (3.-Versuch + keine FS) zusätzlich Skizzen-Block. Für Open-Book-Module (Thermo) Buch-Index-Block. Für e-Exam mit Word Limit (Modern Firm) Antwort-Template-Block.

## ❓ Self-Test-Fragen

5 Fragen, die den ganzen Stoff abdecken. Antworten gehen offline, ohne Material — das ist der Retrieval-Practice-Hebel. Pro Frage 1–2 Sätze Erwartungshorizont mental.

## 🃏 Karten-Themen für `/anki cards <modul-slug> <thema-slug>`

Liste von 6–12 Karten-Vorschlägen — *Themen*, nicht fertige Karten. Tim baut die Karten *nach* dem Durcharbeiten via `/anki`-Skill (Generation Effect).

Pro Eintrag: kurze Beschreibung + (Cloze/Basic/Image-Occlusion). Bei quantitativen Modulen: pro Formel 1 Cloze pro Variable, bei konzeptuellen: Definition + Anwendung + Edge-Case.

## 🧩 Crossovers

Verweise auf andere Module, deren Stoff hier wieder auftaucht oder vorbereitet wird. Wenn nichts: "kein direkter Bezug" — nicht erfinden.

## ✅ Nach der Session (für Heartbeat-Auswertung)

- [ ] Karten in Anki angelegt: ___ neu
- [ ] Verständnis-Score 1–5: ___
- [ ] [modul-spezifischer Check, z. B. "Skizze X aus dem Kopf"] — modul-typ ableitbar
- [ ] Lücken / Stoff für nächste Session: 

> [!info] Auswertung
> Beim nächsten Lernpause-Heartbeat ([[tim/feedback/lernpause-vier-syncs]]) wird dieser Block ausgewertet, fehlende Aspekte ins nächste Pool-Item ergänzt, ggf. Druck-Score angepasst.

---

**Verlinkt mit Pool-Item** in [[projekte/lernplan/<modul-slug>/plan#Phase <N> — <Phasen-Name>]]: *"<Pool-Item-Text aus plan.md>"*
```

## Schritt 4: Vault-Note schreiben

Pfad: `~/Documents/jarvis-wiki/projekte/lernplan/<modul-slug>/lerneinheiten/<YYYY-MM-DD>-<thema-slug>.md`. Verzeichnis bei Bedarf anlegen.

Datei darf nicht überschrieben werden, wenn sie schon existiert — bei Konflikt warnen und mit `--force` erzwingbar oder `<thema-slug>-v2` anhängen lassen.

Auto-Commit-Hook im Vault pusht die Note automatisch — Peer-Host (Container) sieht sie beim nächsten Pull.

## Schritt 5: Todoist-Task patchen

`bash scripts/patch_todoist_task.sh <modul-slug> <thema-slug> <vault-pfad-relativ>` aufrufen.

Das Skript:
1. Sucht in Todoist via REST `/api/v1/tasks/filter?query=today&...` einen Task, dessen Content den Modul-Kürzel + Thema-Stichwort enthält (z. B. "ST: Folien VO01" → matched für `sensortechnik vo01-messkette`).
2. Wenn gefunden: patcht die Task-Description um eine Zeile `🔗 Lerneinheit-Brief: obsidian://open?vault=jarvis-wiki&file=<URL-encoded-Pfad>` (idempotent — wenn schon drin, kein Doppel-Eintrag).
3. Wenn nicht gefunden: kein Auto-Anlegen — stattdessen warnen *"Kein passender Todoist-Task heute gefunden. Brief liegt im Vault, du kannst ihn manuell verlinken oder ich lege auf Wunsch einen neuen Task an."* User entscheidet.

## Schritt 6: Bestätigung

Output:

```
✅ Lerneinheit-Brief erstellt
   Pfad: projekte/lernplan/<modul-slug>/lerneinheiten/<datum>-<thema-slug>.md
   Obsidian: obsidian://open?vault=jarvis-wiki&file=...
   Todoist: <Task-Inhalt> — Description aktualisiert (oder: kein Task gefunden)
   Phase: <N> (<Phasen-Name>) · anki_rolle: <rolle>
```

## Modul-Slug → Anki-Deck Mapping

(identisch zu [[skills/anki|/anki-Skill]])

| Slug | Modul-Kürzel im Brief-Titel |
|---|---|
| `dimm` | DIMM |
| `ppm-seminar` | PPM |
| `entrepreneurial` | Entrep |
| `modern-firm` | MF |
| `international-economics` | IntEco |
| `rvcps` | RVCPS |
| `mldl-auto` | ML/DL |
| `praktikum-rt2` | P-RT2 |
| `sdrt3` | SDRT3 |
| `sensortechnik` | ST |
| `thermo` | Thermo |
| `mpc-ml` | MPC&ML |

## Stolperfallen

- **Brief steht *vor* der Session** — wenn Tim den Stoff schon durchgearbeitet hat und Karten bauen will, ist `/anki cards <modul>` der richtige Weg, nicht `/lerneinheit`.
- **Karten-Themen, nicht Karten** — der Brief listet Themen-Vorschläge für `/anki`, schreibt aber keine fertigen Karten. Generation Effect ist explizit der Grund (siehe [[projekte/lernplan/anki-konzept]]).
- **Modul-Sprache** — bei Modulen mit `klausur.sprache: EN` (RVCPS, Modern Firm, Int. Economics) Brief in EN verfassen. Default ist DE.
- **Phase 4** — keine neuen Lerneinheiten, nur Reviews. Skill blockt das, außer mit `--force`.
- **Pool-Item-Match** — Heuristik kann danebenliegen. Bei "kein Pool-Item gefunden" trotzdem Brief erstellen, aber ohne den Footer-Verweis.
- **Todoist-Match** — Filter `today` reicht oft, aber nicht wenn Task auf morgen geplant ist. Bei No-Match keine Eskalation, nur Warnung.
- **Datei-Konflikt** — wenn Brief für gleiches Datum + Thema schon existiert, nicht überschreiben (Lerntag-Reflektionen darin gehen sonst verloren).

Abschließend `skill-optimize` mit `lerneinheit` aufrufen.

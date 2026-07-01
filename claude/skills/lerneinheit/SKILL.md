---
name: lerneinheit
description: User invokes /lerneinheit to start a new study session for an existing LE (Lerneinheit) OR to create a new LE skeleton. LE files live datumslos under projekte/lernplan/<modul>/lerneinheiten/<einheit-slug>.md with 4 sections (🎯 Lernziele / 📖 Stoffaufnahme / 🔄 Aktiver Abruf / 🩺 Self-Test). Skill prepares reMarkable material if applicable, appends a session entry to the LE, and returns the obsidian:// URL. Todoist-link integration happens automatically via lernplan_eval Heartbeat — NOT via this skill. Konzept-Doku - /workspace/wiki/projekte/lernplan/lerneinheit-konzept.md. Trigger keywords - lerneinheit, /lerneinheit, "ich fang an mit", "lass mich auf X vorbereiten", "session starten für".
disable-model-invocation: true
argument-hint: <modul-slug> <einheit-slug> [--session-min=N]
---

# Lerneinheit — Session-Start für eine LE

LEs (Lerneinheiten) sind **datumslose, deadline-getriebene logische Einheiten** mit 4 Sektionen (🎯 Lernziele / 📖 Stoffaufnahme / 🔄 Aktiver Abruf / 🩺 Self-Test). Pro Modul leben sie unter `projekte/lernplan/<modul>/lerneinheiten/<einheit-slug>.md`. Eine LE kann über mehrere Tage gehen — der Skill startet eine neue Session in einer existierenden LE oder legt eine neue LE als Skelett an.

**Wichtig:** Die Todoist-Integration läuft jetzt **vollautomatisch über den Heartbeat** (`lernplan_eval.py --mode=morning`) — der Heartbeat setzt den Obsidian-Deep-Link direkt im Todoist-Task, ohne diesen Skill. Dieser Skill ist nur noch für **Session-Vorbereitung** zuständig: reMarkable-Material, Lernziele-Recap, Session-Tagebuch-Eintrag.

Konzept-Kontext: [[projekte/lernplan/lerneinheit-konzept]], [[projekte/lernplan/methodik]], [[projekte/lernplan/anki-konzept]].

## Voraussetzungen

- Tools: `python3`, optional `rmapi` für reMarkable-Upload
- Datei: `~/Documents/jarvis-wiki/projekte/lernplan/lerneinheit-konzept.md`

Voraussetzungen gemäß `requirement-checker` Skill validieren.

## Schritt 1: Argumente parsen

Erwartet: `<modul-slug> <einheit-slug> [--session-min=N]`

- `modul-slug`: einer der 12 Slugs (Liste unten)
- `einheit-slug`: kebab-case Slug der LE (z.B. `kap01-konzepte`, `vo01-einfuehrung`, `paper-acemoglu-2001`)
- `--session-min=N`: Dauer dieser Session in Minuten (default 75)

## Schritt 2: LE-Datei laden ODER Skelett anlegen

Pfad: `~/Documents/jarvis-wiki/projekte/lernplan/<modul-slug>/lerneinheiten/<einheit-slug>.md`

**Falls Datei existiert:**
- Frontmatter lesen (`status`, `deadline`, `modul-phase`, `karten-ziel`, `geplante-minuten`)
- Status-Check: wenn `status: abgeschlossen` → warnen *"LE bereits abgeschlossen — neue Session sicher gewünscht? (z.B. Nacharbeit-Status setzen)"*
- Modul-Phase 4 = keine neuen LE-Sessions → warnen *"Modul-Phase 4 (Pre-Klausur) = Klausur-Hygiene, normalerweise nur Anki-Reviews"*

**Falls Datei nicht existiert:**
- Skelett anlegen gemäß Konzept-Doku Sektion 4 (4 Sektionen, leere Checkboxes mit Item-Typ-Tags)
- Frontmatter aus `modul.md` `le-profil:` ableiten (unit-typ, block-defaults)
- Deadline: in Absprache mit Tim (Default: heute + 7 Tage)

## Schritt 3: Modul-Kontext laden

Aus `~/Documents/jarvis-wiki/projekte/lernplan/<modul-slug>/modul.md`:
- `klausur.sprache` → Brief in dieser Sprache
- `anki_rolle` → Anki-Empfehlung im Brief
- `modul_typ` → Lernmethoden-Mix (siehe Konzept-Doku)
- `phasen:`-Block → aktive Modul-Phase (Phase 4 = Warnung)
- `le-profil.block-defaults` → falls Skelett angelegt werden muss

Aus `~/Documents/jarvis-wiki/projekte/lernplan/<modul-slug>/tracker.md`:
- Modul-Cockpit-Status (welche LEs sind in welcher Phase 🔴🟡🟢)

## Schritt 4: reMarkable-Material vorbereiten (optional)

Nur wenn Stoffaufnahme-Block der LE Folien/Skript-Verweise hat:

```bash
FOLDER=$(bash ~/.claude/skills/remarkable-upload/scripts/rm.sh slug_to_folder <modul-slug>)
# Pro identifiziertem PDF (aus 📖 Stoffaufnahme-Checkboxes):
bash ~/.claude/skills/remarkable-upload/scripts/rm.sh put <local-pfad> "$FOLDER/"
```

Failsoft: wenn rmapi nicht erreichbar → Skill bricht nicht ab, warnt nur.

## Schritt 5: Session-Tagebuch-Eintrag anlegen

In `## 📅 Sessions`-Sektion der LE-Datei einen neuen Eintrag anhängen:

```markdown
### YYYY-MM-DD Nmin (Phase: <stoffaufnahme|aktiver_abruf|self_test>)
- (Eintrag wird von Tim nach der Session gefüllt — was wurde gemacht, welche Karten, Lücken)
```

Falls Sessions-Sektion noch nicht existiert: anlegen.

## Schritt 6: Bestätigung + Obsidian-URL

Output:

```
✅ LE-Session vorbereitet
   Vault: projekte/lernplan/<modul>/lerneinheiten/<einheit-slug>.md
   Obsidian: obsidian://open?vault=jarvis-wiki&file=<url-encoded-path>
   Status: <status> · Deadline: <YYYY-MM-DD> · Phase: <id>
   reMarkable: <N> Files in /Studium/<Modul>/ (oder: keine vorbereitet)
   Nächste offene Checkbox: <block> — "<text>" (<Xmin>)
```

## Schritt 7: Status-Update prompten

Frage Tim am Ende: *"LE-Status aktualisieren? geplant → aktiv? Soll ich das Frontmatter setzen?"*

Wenn ja: `status: aktiv` ins Frontmatter, `updated: <today>` setzen.

## Modul-Slug → Anki-Deck Mapping

(identisch zu `/anki`-Skill)

| Slug | Modul-Kürzel |
|---|---|
| `dimm` | DIMM |
| `ppm-seminar` | PPM |
| `entrepreneurial` | Entrep |
| `modern-firm` | MF |
| `international-economics` | International-Economics |
| `rvcps` | RVCPS |
| `mldl-auto` | ML/DL |
| `praktikum-rt2` | P-RT2 |
| `sdrt3` | SDRT3 |
| `sensortechnik` | ST |
| `thermo` | Thermo |
| `mpc-ml` | MPC&ML |

## Was sich vs. alter Skill geändert hat (Big-Bang 2026-05-13)

- **Datumslose Filenames** statt `<YYYY-MM-DD>-<thema>.md` — eine LE lebt über mehrere Tage als ein File
- **Frontmatter-Schema neu** — `deadline`, `modul-phase`, `unit-typ`, `geplante-minuten` (siehe Konzept-Doku Sektion 3)
- **4-Sektionen-Body** statt Block-Plan + Material + Self-Test — entspricht Lernforschung (Retrieval × Spacing)
- **plan.md → strategie.md** als Referenz
- **Todoist-Patch entfällt** — `lernplan_eval --mode=morning` setzt den Obsidian-Link beim Push direkt
- **Varianten A/B/C eliminiert** — eine universelle LE-Struktur statt Stoff/Anki-Bau/Setup-Varianten. Anki-Bau ist Block 🔄 in der Stoff-LE, Setup-Mikrotasks wandern in eine separate LE mit `unit-typ: setup` ohne Modul-Phase-Bindung.

## Stolperfallen

- **LE-Datei existiert schon mit altem Datums-Schema?** → Manuell migrieren (Inhalt in datumslose Datei kopieren, Frontmatter anpassen, alte Datei löschen). Siehe Konzept-Doku Sektion 12.
- **`einheit-slug` matched keine bestehende LE?** → Skelett anlegen, NICHT Brief erzwingen.
- **Modul-Phase 4** → Skill warnt, User entscheidet mit `--force`.
- **Sessions-Block voll** → niemals löschen, immer anhängen (Audit-Spur).

## Verlinkt mit Konzept

- [[projekte/lernplan/lerneinheit-konzept]] — Konzept-Doku (Single Source of Truth)
- [[projekte/lernplan/methodik]] — Lernmethodik-Foundation
- [[projekte/lernplan/anki-konzept]] — Anki-Workflow
- [[tim/feedback/lerneinheit-self-test-zweck]] — Self-Test als Diagnose
- [[tim/feedback/lerneinheit-kontrollfragen-zentriert]] — KF-Modul-Spezialfall (Sensortechnik)

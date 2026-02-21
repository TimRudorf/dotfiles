---
name: uni-init-project
description: This skill should be used when the user asks to "initialize a uni project",
  "set up a learning project", "init Lernprojekt", "download Moodle materials",
  "Moodle-Kurs herunterladen", or uses /uni-init-project. It downloads course materials
  from Moodle (optional), creates a standardized folder structure, sorts files,
  normalizes filenames, and generates a CLAUDE.md.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
argument-hint: "[Moodle-Kurs-URL]"
disable-model-invocation: true
---

# Uni-Lernprojekt initialisieren

Initialisiert ein Uni-Lernprojekt mit standardisierter Ordnerstruktur. Optional Moodle-Kurs-URL als Argument — dann werden Kursmaterialien automatisch heruntergeladen und Kursinfos aus der Moodle API bezogen.

## Schritt 0: Moodle-Token validieren (nur Modus A)

Nur ausführen wenn `$ARGUMENTS` eine URL enthält (beginnt mit `https://`).

Prüfe ob `~/.config/moodle-dl/token.json` existiert (Format: `{"domain": "...", "token": "..."}`).

Falls vorhanden → Token lesen, weiter mit Schritt 1.

Falls nicht vorhanden → User via `AskUserQuestion` fragen:
- Frage: "Für den Moodle-Download wird einmalig ein API-Token benötigt. Das Setup startet `moodle-dl --init --sso` — du wirst im Browser zur Anmeldung weitergeleitet."
- Optionen: "Token einrichten" / "Abbrechen"

Bei "Abbrechen" → Skill abbrechen.

Bei "Token einrichten":
1. `pip install moodle-dl` falls `moodle-dl` nicht installiert
2. Temporäres Verzeichnis erstellen: `mktemp -d`
3. In tmpdir: `moodle-dl --init --sso` ausführen (interaktiv, User meldet sich im Browser an)
4. Aus der erzeugten `config.json` im tmpdir die Felder `moodle_domain` und `token` extrahieren
5. Nach `~/.config/moodle-dl/token.json` speichern: `{"domain": "<moodle_domain>", "token": "<token>"}`
6. tmpdir aufräumen (`rm -rf`)

## Schritt 1: Argument prüfen & Informationen sammeln

### Argument-Erkennung

- Falls `$ARGUMENTS` eine URL enthält (beginnt mit `https://`) → **Modus A** (Moodle-Download)
- Sonst → **Modus B** (manuell)

### Modus A: Moodle-URL gegeben

**1a) Kursinfo abrufen:**

1. Domain und Kurs-ID aus URL extrahieren (z.B. `https://moodle.tu-darmstadt.de/course/view.php?id=12345` → domain=`moodle.tu-darmstadt.de`, id=`12345`)
2. Token aus `~/.config/moodle-dl/token.json` lesen
3. Kursname via Moodle API abrufen:
   ```
   curl -s "https://{domain}/webservice/rest/server.php?wstoken={token}&wsfunction=core_course_get_courses_by_field&field=id&value={id}&moodlewsrestformat=json"
   ```
4. Kursnamen aus Response extrahieren (`.courses[0].fullname`)
5. User via `AskUserQuestion` fragen:
   - Kursname bestätigen/anpassen
   - Abschluss (Master/Bachelor)
   - Semester (z.B. WiSe 25/26, SoSe 26)

**1c) Materialien herunterladen:**

1. Kursinhalte via Moodle API abrufen:
   ```
   curl -s "https://{domain}/webservice/rest/server.php?wstoken={token}&wsfunction=core_course_get_contents&courseid={id}&moodlewsrestformat=json"
   ```
2. Alle Einträge mit `type: "file"` aus der Response sammeln
3. Jede Datei flach ins aktuelle Verzeichnis herunterladen:
   ```
   curl -L --fail -o "{filename}" "{fileurl}?token={token}"
   ```
4. Duplikate (gleicher Dateiname bereits vorhanden) überspringen
5. Download-Zusammenfassung anzeigen (Anzahl heruntergeladener Dateien, übersprungene Duplikate)

Bei API-Fehlern (HTTP-Fehler, leere Response, `exception` in JSON) → klare Fehlermeldung und Skill abbrechen.

### Modus B: Ohne Moodle-URL

Frage den Benutzer (sofern nicht bereits bekannt):
- **Fachname** (z.B. "Systemdynamik und Regelungstechnik 3")
- **Abschluss** (z.B. Master, Bachelor)
- **Semester** (z.B. WiSe 25/26, SoSe 26)

## Schritt 2: Ordnerstruktur erstellen

Erstelle folgende Verzeichnisstruktur im aktuellen Projektordner:

```
docs/
├── Skript/
├── Übungen/
│   ├── Aufgaben/
│   ├── Lösungen/
│   └── Weiteres/
├── Probeklausur/
└── Sonstiges/
```

## Schritt 3: Vorhandene Dateien einordnen

1. Scanne das gesamte Projektverzeichnis nach vorhandenen Dateien (PDFs und andere Dokumente).
2. Ordne die Dateien automatisch anhand ihres Namens in die passenden Ordner ein:
   - Dateien mit "Skript" oder "Vorlesung" im Namen → `docs/Skript/`
   - Dateien mit "Aufgabe" oder "Übung" oder "Blatt" im Namen → `docs/Übungen/Aufgaben/`
   - Dateien mit "Lösung" oder "Loesung" oder "Musterlösung" im Namen → `docs/Übungen/Lösungen/`
   - Dateien mit "Klausur" oder "Exam" oder "Prüfung" im Namen → `docs/Probeklausur/`
   - Alle anderen Dokumente → `docs/Sonstiges/`

## Schritt 4: Dateinamen normalisieren

Analysiere die Dateinamen **pro Ordner** und prüfe:
- **Trennzeichen**: Unterstriche, Bindestriche, Leerzeichen oder CamelCase gemischt? → Vereinheitlichen
- **Nummerierung**: Uneinheitlich (`01` vs `1` vs `001`)? → Auf gleiche Stellenanzahl normalisieren
- **Groß-/Kleinschreibung**: Gemischt? → Vereinheitlichen
- **Präfixe/Suffixe**: Unterschiedliche Konventionen? → Auf das häufigste Schema angleichen
- **Sprache**: Deutsch/Englisch gemischt beibehalten, aber Schreibweise vereinheitlichen

Identifiziere das dominante Schema pro Ordner. Falls >90% der Dateien bereits konsistent sind, nichts ändern. Andernfalls abweichende Dateien mit `mv` umbenennen.

## Schritt 5: CLAUDE.md erstellen

Erstelle eine `CLAUDE.md` im Projektstamm mit folgendem Aufbau:

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Überblick

Dieses Repository enthält die Kursmaterialien für **{Fachname}** ({Abschluss}, {Semester}). Es handelt sich um eine reine Dokumentensammlung (PDFs), kein Software-Projekt.

## Verzeichnisstruktur

{Tatsächliche Verzeichnisstruktur mit allen einsortierten Dateien als Tree-Darstellung}

## Hinweise für Claude

- Alle Inhalte liegen als PDF vor. Zum Lesen ist `poppler` nötig (`brew install poppler`).
- Die Aufgaben- und Lösungsnummerierung ist konsistent (AufgabenXX ↔ LoesungenXX usw.).
- Bei fachlichen Fragen ist das Skript (`docs/Skript/`) die primäre Quelle.
- Zusatzmaterial unter `Weiteres/` behandelt spezifische Methoden.
```

Passe die Verzeichnisstruktur an die tatsächlich vorhandenen Dateien an. Füge Kommentare hinzu, die den Inhalt der Dateien beschreiben.

## Schritt 6: Zusammenfassung anzeigen

Zeige dem Benutzer:
- Welche Ordner erstellt wurden
- Welche Dateien wohin verschoben wurden
- Welche Dateien umbenannt wurden (alter Name → neuer Name), oder dass keine Umbenennung nötig war
- Dass die CLAUDE.md erstellt wurde

## Regeln

- **Sprache**: Deutsch mit echten Umlauten (ä, ö, ü, ß)
- **Ordnerstruktur** ist fix (`docs/Skript`, `docs/Übungen/Aufgaben` etc.) — keine abweichenden Pfade
- **Versteckte Dateien**, `.DS_Store` und `CLAUDE.md` ignorieren
- **`mkdir -p`** für Ordnererstellung verwenden
- Bei **Unsicherheit bei Dateizuordnung**: User fragen
- **CLAUDE.md immer zuletzt** erstellen (nach Umbenennung, damit der Tree aktuell ist)
- **Token** zentral in `~/.config/moodle-dl/token.json` speichern und wiederverwenden
- **Downloads** mit `curl -L --fail` ausführen
- Bei **API-Fehlern** → klare Fehlermeldung und Abbruch
- **Duplikate** (gleicher Dateiname) beim Download überspringen

---

## Skill-Optimierung

Nach Abschluss dieses Skills kurz bewerten, ob Optimierungsbedarf besteht:

- **Empfehlung "ja"**: Fehler aufgetreten, Workarounds nötig, Befehle wiederholt, User-Korrekturen
- **Empfehlung "nein"**: Reibungsloser Lauf wie dokumentiert

Per `AskUserQuestion` fragen:

> Skill abgeschlossen. Soll die Skill-Dokumentation optimiert werden?
> Empfehlung: {ja — [kurzer Grund] | nein — Lauf war reibungslos}

Optionen: **"Ja, optimieren"**, **"Nein"**

Bei "Ja": `skill-optimize` mit Skill-Name `uni-init-project` ausführen.

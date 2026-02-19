---
name: init-uni-project
description: This skill should be used when the user asks to "initialize a uni project",
  "set up a learning project", "init Lernprojekt", or uses /init-uni-project. It creates
  a standardized folder structure, sorts existing files, normalizes filenames, and generates
  a CLAUDE.md for university course materials.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
argument-hint: "[Fachname] [Abschluss] [Semester]"
disable-model-invocation: true
---

# Uni-Lernprojekt initialisieren

Initialisiert ein Uni-Lernprojekt mit standardisierter Ordnerstruktur. Der Benutzer gibt Fachname, Abschluss und Semester über `$ARGUMENTS` — falls nicht gegeben, danach fragen.

## Schritt 1: Informationen sammeln

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

---

## Skill-Optimierung

Nach Abschluss dieses Skills kurz bewerten, ob Optimierungsbedarf besteht:

- **Empfehlung "ja"**: Fehler aufgetreten, Workarounds nötig, Befehle wiederholt, User-Korrekturen
- **Empfehlung "nein"**: Reibungsloser Lauf wie dokumentiert

Per `AskUserQuestion` fragen:

> Skill abgeschlossen. Soll die Skill-Dokumentation optimiert werden?
> Empfehlung: {ja — [kurzer Grund] | nein — Lauf war reibungslos}

Optionen: **"Ja, optimieren"**, **"Nein"**

Bei "Ja": `skill-optimize` mit Skill-Name `init-uni-project` ausführen.

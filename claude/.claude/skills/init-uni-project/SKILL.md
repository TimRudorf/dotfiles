---
name: init-uni-project
description: Initialisiert ein Uni-Lernprojekt mit standardisierter Ordnerstruktur und CLAUDE.md
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
argument-hint: "[Fachname] [Abschluss] [Semester]"
---

Du initialisierst ein Uni-Lernprojekt. Der Benutzer gibt dir den Fachnamen, Abschluss (z.B. Master, Bachelor) und das Semester (z.B. WiSe 25/26).

Falls diese Infos nicht über `$ARGUMENTS` gegeben wurden, frage den Benutzer danach.

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

Verwende `mkdir -p` um alle Ordner auf einmal zu erstellen.

## Schritt 3: Vorhandene Dateien einordnen

1. Scanne das gesamte Projektverzeichnis nach vorhandenen Dateien (PDFs und andere Dokumente).
2. Ordne die Dateien automatisch anhand ihres Namens in die passenden Ordner ein:
   - Dateien mit "Skript" oder "Vorlesung" im Namen → `docs/Skript/`
   - Dateien mit "Aufgabe" oder "Übung" oder "Blatt" im Namen → `docs/Übungen/Aufgaben/`
   - Dateien mit "Lösung" oder "Loesung" oder "Musterlösung" im Namen → `docs/Übungen/Lösungen/`
   - Dateien mit "Klausur" oder "Exam" oder "Prüfung" im Namen → `docs/Probeklausur/`
   - Alle anderen Dokumente → `docs/Sonstiges/`
3. Falls Dateien nicht eindeutig zugeordnet werden können, frage den Benutzer wo sie hin sollen.
4. Ignoriere `.DS_Store`, `CLAUDE.md` und versteckte Dateien/Ordner.

## Schritt 3b: Dateinamen-Konsistenz prüfen und herstellen

Analysiere die Dateinamen **pro Ordner** und entscheide selbstständig, ob ein konsistentes Naming-Schema vorliegt. Prüfe dabei:

- **Trennzeichen**: Werden gemischt Unterstriche (`_`), Bindestriche (`-`), Leerzeichen oder CamelCase verwendet? → Vereinheitlichen auf ein Schema.
- **Nummerierung**: Sind Nummern unterschiedlich formatiert (z.B. `01` vs `1` vs `001`)? → Auf einheitliche Stellenanzahl normalisieren (z.B. zweistellig `01`, `02`, ... oder dreistellig je nach Anzahl).
- **Groß-/Kleinschreibung**: Sind manche Dateien groß, andere klein geschrieben? → Vereinheitlichen.
- **Präfixe/Suffixe**: Haben zusammengehörige Dateien unterschiedliche Namenskonventionen (z.B. `Klausur_SS15.pdf` vs `Klausur SS15.pdf`)? → Auf das häufigste Schema angleichen.
- **Sprache**: Wird gemischt Deutsch und Englisch verwendet? → Beibehalten, aber Schreibweise vereinheitlichen.

**Vorgehen:**
1. Liste alle Dateien pro Unterordner auf und identifiziere das dominante Naming-Schema (das von der Mehrheit der Dateien verwendet wird).
2. Falls das Naming bereits konsistent ist (>90% der Dateien folgen dem gleichen Schema), nimm keine Änderungen vor.
3. Falls Inkonsistenzen bestehen, benenne die abweichenden Dateien so um, dass sie dem dominanten Schema folgen. Verwende `mv` zum Umbenennen.
4. Zeige in der Zusammenfassung (Schritt 5) an, welche Dateien umbenannt wurden (alter Name → neuer Name).

## Schritt 4: CLAUDE.md erstellen (nach eventuellem Umbenennen!)

Erstelle eine `CLAUDE.md` im Projektstamm mit folgendem Aufbau:

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Überblick

Dieses Repository enthält die Kursmaterialien für **{Fachname}** ({Abschluss}, {Semester}). Es handelt sich um eine reine Dokumentensammlung (PDFs), kein Software-Projekt.

## Verzeichnisstruktur

\```
{Tatsächliche Verzeichnisstruktur mit allen einsortierten Dateien als Tree-Darstellung}
\```

## Hinweise für Claude

- Alle Inhalte liegen als PDF vor. Zum Lesen ist `poppler` nötig (`brew install poppler`).
- Die Aufgaben- und Lösungsnummerierung ist konsistent (AufgabenXX ↔ LoesungenXX usw.).
- Bei fachlichen Fragen ist das Skript (`docs/Skript/`) die primäre Quelle.
- Zusatzmaterial unter `Weiteres/` behandelt spezifische Methoden.
```

Passe die Verzeichnisstruktur an die tatsächlich vorhandenen Dateien an. Füge Kommentare hinzu, die den Inhalt der Dateien beschreiben.

## Schritt 5: Zusammenfassung

Zeige dem Benutzer eine Zusammenfassung:
- Welche Ordner erstellt wurden
- Welche Dateien wohin verschoben wurden
- Welche Dateien umbenannt wurden (alter Name → neuer Name), oder dass keine Umbenennung nötig war
- Dass die CLAUDE.md erstellt wurde

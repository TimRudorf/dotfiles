---
name: lernzusammenfassung
description: Erstellt eine Lernzusammenfassung zu einem Übungsblatt mit Theorie, Kochrezepten und Klausurtipps
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, mcp__context7__resolve-library-id, mcp__context7__query-docs
argument-hint: "[Übungsnummer, z.B. 03]"
---

Du erstellst eine Lernzusammenfassung zu einem bestimmten Übungsblatt. Der Benutzer gibt dir die Übungsnummer (z.B. `03`).

Falls die Übungsnummer nicht über `$ARGUMENTS` gegeben wurde, frage den Benutzer danach.

## Schritt 1: Projektstruktur erkennen

1. Lies die `CLAUDE.md` im aktuellen Projektverzeichnis, um die Verzeichnisstruktur und das Fach zu verstehen.
2. Identifiziere:
   - Das Aufgabenblatt: `docs/Übungen/Aufgaben/Aufgaben{Nr}.pdf`
   - Die Musterlösung: `docs/Übungen/Lösungen/Loesungen{Nr}.pdf`
   - Das Vorlesungsskript: `docs/Skript/Skript.pdf` (oder ähnlich)
   - Zusatzmaterial: `docs/Übungen/Weiteres/` und `docs/Sonstiges/`
3. Falls Dateien nicht am erwarteten Ort liegen, suche mit Glob nach passenden Dateien.

## Schritt 2: Inhalte lesen und analysieren

1. Lies das **Aufgabenblatt** und die **Musterlösung** vollständig.
2. Identifiziere die behandelten **Themen und Methoden** (z.B. Ljapunov-Stabilität, Popov-Kriterium, Zustandsregler, etc.).
3. Lies die **relevanten Kapitel des Skripts** zu diesen Themen. Orientiere dich am Inhaltsverzeichnis des Skripts, um die richtigen Seiten zu finden.
4. Prüfe, ob unter `docs/Übungen/Weiteres/` **Zusatzmaterial** zu den identifizierten Themen existiert (z.B. `Kochrezept_Popov.pdf`). Falls ja, lies es ebenfalls.

## Schritt 3: Formatentscheidung

Entscheide basierend auf dem Inhalt:

- **Markdown** (`sum/Zusammenfassung{Nr}.md`): Wenn die Zusammenfassung hauptsächlich aus Text, einfachen Aufzählungen und wenigen Formeln besteht. Einfache Inline-Formeln wie `$x^2$` sind in Markdown okay.
- **LaTeX → PDF** (`sum/Zusammenfassung{Nr}.pdf`): Wenn die Zusammenfassung viele mathematische Formeln, Matrizen, Blockdiagramme oder komplexe Darstellungen enthält. Dies ist der Regelfall bei ingenieurwissenschaftlichen Fächern.

Im Zweifelsfall wähle **LaTeX → PDF**.

## Schritt 4: Zusammenfassung erstellen

Erstelle die Zusammenfassung auf **Deutsch** mit folgenden Abschnitten:

### 1. Themenübersicht
- Kurze Auflistung aller behandelten Themen des Übungsblatts
- Zuordnung zu den relevanten Skript-Kapiteln

### 2. Theoriezusammenfassung
- Verständliche Erklärung der theoretischen Grundlagen
- Wichtige Definitionen und Sätze
- Zentrale Formeln mit Erläuterung der Variablen
- Zusammenhänge zwischen den Konzepten

### 3. Kochrezepte
- **Schritt-für-Schritt-Anleitungen** für jeden Aufgabentyp
- Klar nummerierte Schritte, die man in der Klausur direkt anwenden kann
- Angabe, welche Formeln/Sätze in welchem Schritt verwendet werden
- Falls im Zusatzmaterial (`Weiteres/`) bereits Kochrezepte existieren, diese als Basis verwenden und ggf. ergänzen

### 4. Typische Fehler und Vermeidung
- Häufige Fehlerquellen bei den behandelten Themen
- Worauf man besonders achten muss
- Hinweise aus der Musterlösung, wo Studierende typischerweise Fehler machen

### 5. Tipps und Tricks
- Abkürzungen und Vereinfachungen für die Klausur
- Plausibilitätschecks zur Selbstkontrolle
- Merkregeln und Eselsbrücken

## Context7 MCP Server

Nutze den **Context7 MCP Server** (`mcp__context7__resolve-library-id` + `mcp__context7__query-docs`) in folgenden Situationen:

### Bei LaTeX-Problemen
- **Kompilierungsfehler:** Schlage die Dokumentation des betroffenen LaTeX-Pakets nach (z.B. `mdframed`, `amsmath`, `mathtools`), um korrekte Syntax und Optionen zu finden.
- **Unbekannte Umgebungen/Befehle:** Wenn ein spezieller LaTeX-Befehl benötigt wird (z.B. für Matrizen, spezielle Symbole, Diagramme), nutze Context7 um die korrekte Syntax nachzuschlagen.
- **Paket-Optionen:** Bei Unsicherheit über verfügbare Optionen eines Pakets (z.B. `mdframed`-Rahmenoptionen, `geometry`-Ränder).

### Bei fachlichen Inhalten
- **Mathematische Notation:** Wenn unsicher ist, wie ein bestimmtes mathematisches Symbol oder Konstrukt in LaTeX korrekt dargestellt wird.
- **Ergänzende Erklärungen:** Falls ein Konzept aus dem Skript unklar ist und eine alternative Erklärung helfen könnte, kann Context7 genutzt werden, um Dokumentation zu relevanten Bibliotheken (z.B. MATLAB/Simulink-Dokumentation bei regelungstechnischen Themen) nachzuschlagen.

### Workflow
1. Zuerst `mcp__context7__resolve-library-id` aufrufen, um die korrekte Library-ID zu ermitteln
2. Dann `mcp__context7__query-docs` mit der ermittelten ID und einer spezifischen Frage aufrufen
3. **Maximal 3 Aufrufe pro Zusammenfassung** -- nur bei konkretem Bedarf, nicht routinemäßig

## Schritt 5: Datei speichern

### Bei Markdown:
Speichere die Zusammenfassung als `sum/Zusammenfassung{Nr}.md`.

### Bei LaTeX → PDF:
1. Erstelle die LaTeX-Datei `sum/Zusammenfassung{Nr}.tex` mit folgenden Einstellungen:
   - `\documentclass[a4paper,11pt]{article}`
   - `\usepackage[ngerman]{babel}` für deutsche Sprache
   - `\usepackage[utf8]{inputenc}` und `\usepackage[T1]{fontenc}`
   - `\usepackage{amsmath,amssymb,mathtools}` für Mathematik
   - `\usepackage{geometry}` mit sinnvollen Rändern
   - `\usepackage{enumitem}` für Aufzählungen
   - `\usepackage{mdframed}` für farbige Boxen (Kochrezepte, Tipps) -- **nicht** `tcolorbox` verwenden (Tagging-Inkompatibilität mit LaTeX 2024+ Kernel erzeugt Debug-Output auf Seite 1)
   - `\usepackage{hyperref}` für Verlinkungen
   - `\usepackage{booktabs}` für Tabellen
   - `\usepackage{fancyhdr}` für Kopf-/Fußzeilen
   - `\usepackage{xcolor}` für Farben
   - `\usepackage{parskip}` für Absatzabstände statt Einrückung
2. Verwende `mdframed`-Umgebungen für farbige Boxen:
   - **Definitionen/Sätze**: blaue Box (`backgroundcolor=defblue!5, linecolor=defblue!80`)
   - **Kochrezepte**: grüne Box (`backgroundcolor=recipegreen!5, linecolor=recipegreen!80`)
   - **Warnungen/Typische Fehler**: rote Box (`backgroundcolor=warnred!5, linecolor=warnred!80`)
   - **Tipps**: gelbe Box (`backgroundcolor=tipyellow!5, linecolor=tipyellow!80`)
   - Definiere `\newenvironment` mit `mdframed` und farbigem Titel via `\textbf{\textcolor{...}{Titel}}`
3. **LaTeX-Pakete prüfen und installieren:** Vor der Kompilierung sicherstellen, dass alle benötigten Pakete installiert sind. Falls ein Paket fehlt (z.B. `tikzfill` für `tcolorbox[most]`), installiere es mit:
   ```bash
   sudo /Library/TeX/texbin/tlmgr install <paketname>
   ```
   Falls `sudo` nicht möglich ist (kein Terminal-Passwort), bitte den Benutzer, den Befehl manuell auszuführen.
4. Kompiliere mit `pdflatex` unter Verwendung des **absoluten Pfads** (da `/Library/TeX/texbin/` nicht im PATH ist):
   ```bash
   /Library/TeX/texbin/pdflatex -interaction=nonstopmode -output-directory="<sum-Verzeichnis>" "<tex-Datei>"
   ```
   Zweimal ausführen für korrekte Referenzen.
5. Räume Hilfsdateien auf (`.aux`, `.log`, `.out`, `.toc`), behalte aber die `.tex`-Datei.
6. Falls die Kompilierung fehlschlägt, analysiere die `.log`-Datei:
   - **Fehlendes Paket** (`File '...' not found`): Mit `tlmgr install` nachinstallieren
   - **Syntaxfehler**: In der `.tex`-Datei beheben und erneut kompilieren

## Schritt 6: Qualitätsprüfung (Feedback-Loop)

Nach erfolgreicher Kompilierung das erzeugte PDF mit dem Read-Tool öffnen und **systematisch prüfen**:

### Strukturprüfung
- Sind **alle 5 Abschnitte** vorhanden? (Themenübersicht, Theoriezusammenfassung, Kochrezepte, Typische Fehler, Tipps und Tricks)
- Sind die `mdframed`-Boxen korrekt gerendert? (blaue Definitions-Boxen, grüne Kochrezept-Boxen, rote Warnungen, gelbe Tipps)
- Ist die Formatierung sauber? (keine abgeschnittenen Formeln, keine Overfull-Boxen, kein Text außerhalb der Seitenränder)

### Inhaltsprüfung
- Deckt die Themenübersicht **alle Aufgaben** des Übungsblatts ab?
- Enthält die Theoriezusammenfassung die **zentralen Definitionen und Formeln** zu jedem Thema?
- Gibt es für **jeden Aufgabentyp** ein Kochrezept mit nummerierten Schritten?
- Sind die Formeln **korrekt** wiedergegeben (Vergleich mit Skript und Musterlösung)?
- Sind die Tipps und typischen Fehler **spezifisch** für die Übungsthemen (nicht generisch)?

### Iterieren bei Mängeln
Falls Mängel gefunden werden:
1. Identifiziere die konkreten Probleme (z.B. fehlender Abschnitt, falsche Formel, kaputtes Layout)
2. Behebe die Probleme in der `.tex`-Datei
3. Kompiliere erneut (zweimal)
4. Prüfe das PDF erneut
5. Wiederhole bis alle Prüfpunkte bestanden sind

**Maximal 3 Iterationen.** Falls danach noch Probleme bestehen, dem Benutzer die verbleibenden Mängel mitteilen.

## Schritt 7: Zusammenfassung anzeigen

Zeige dem Benutzer:
- Welche Quellen verwendet wurden (Aufgabenblatt, Lösung, Skript-Kapitel, Zusatzmaterial)
- Welche Themen behandelt werden
- Wo die Zusammenfassung gespeichert wurde
- Bei PDF: Bestätige erfolgreiche Kompilierung
- Ergebnis der Qualitätsprüfung (bestanden / welche Korrekturen durchgeführt wurden)

---
name: lernzusammenfassung
description: This skill should be used when the user asks to create a learning summary,
  Lernzusammenfassung, or Zusammenfassung for a Uebungsblatt or exercise sheet.
  It reads the exercise PDF, solution PDF, and lecture notes, then writes a structured
  LaTeX PDF (or Markdown) summary with theory, step-by-step recipes, and exam tips.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, mcp__context7__resolve-library-id, mcp__context7__query-docs
argument-hint: "[Übungsnummer, z.B. 03]"
disable-model-invocation: true
---

# Lernzusammenfassung erstellen

Erstellt eine strukturierte Lernzusammenfassung zu einem Übungsblatt. Der Benutzer gibt die Übungsnummer (z.B. `03`) über `$ARGUMENTS` — falls nicht gegeben, danach fragen.

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

Standard ist **LaTeX → PDF** (`sum/Zusammenfassung{Nr}.pdf`). Markdown (`sum/Zusammenfassung{Nr}.md`) nur bei reinen Text-Zusammenfassungen ohne nennenswerte Formeln.

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

## Schritt 5: Datei speichern

### Bei Markdown:
Speichere die Zusammenfassung als `sum/Zusammenfassung{Nr}.md`.

### Bei LaTeX → PDF:
1. Erstelle die LaTeX-Datei `sum/Zusammenfassung{Nr}.tex`. Lies `reference.md` (im Skill-Verzeichnis) für die vollständige Preamble, Farb-Definitionen und mdframed-Umgebungen.

> **Wichtig:** Verwende **nicht** `tcolorbox` — Tagging-Inkompatibilität mit dem LaTeX 2024+ Kernel erzeugt Debug-Output auf Seite 1.

2. Kompiliere mit `pdflatex` unter Verwendung des **absoluten Pfads** (da `/Library/TeX/texbin/` nicht im PATH ist):
   ```bash
   /Library/TeX/texbin/pdflatex -interaction=nonstopmode -output-directory="<sum-Verzeichnis>" "<tex-Datei>"
   ```
   Zweimal ausführen für korrekte Referenzen.
3. Räume Hilfsdateien auf (`.aux`, `.log`, `.out`, `.toc`), behalte aber die `.tex`-Datei.
4. Falls die Kompilierung fehlschlägt, analysiere die `.log`-Datei:
   - **Fehlendes Paket** (`File '...' not found`): Mit `/Library/TeX/texbin/tlmgr install <paketname>` nachinstallieren. Falls Berechtigungsfehler, den User bitten den Befehl manuell auszuführen.
   - **Syntaxfehler**: In der `.tex`-Datei beheben und erneut kompilieren

## Schritt 6: Qualitätsprüfung

Nach erfolgreicher Kompilierung das erzeugte PDF mit dem Read-Tool öffnen und prüfen:

**Struktur** — Alle 5 Abschnitte vorhanden? mdframed-Boxen korrekt gerendert? Keine abgeschnittenen Formeln oder Overfull-Boxen?

**Inhalt** — Themenübersicht deckt alle Aufgaben ab? Zentrale Definitionen und Formeln enthalten? Kochrezept für jeden Aufgabentyp? Formeln korrekt (Vergleich mit Skript/Musterlösung)? Tipps spezifisch statt generisch?

Bei Mängeln: beheben, erneut kompilieren, erneut prüfen. **Maximal 3 Iterationen.** Danach verbleibende Mängel dem Benutzer mitteilen.

## Schritt 7: Zusammenfassung anzeigen

Zeige dem Benutzer:
- Welche Quellen verwendet wurden (Aufgabenblatt, Lösung, Skript-Kapitel, Zusatzmaterial)
- Welche Themen behandelt werden
- Wo die Zusammenfassung gespeichert wurde
- Bei PDF: Bestätige erfolgreiche Kompilierung
- Ergebnis der Qualitätsprüfung (bestanden / welche Korrekturen durchgeführt wurden)

## Regeln

- **Sprache**: Deutsch mit echten Umlauten (ä, ö, ü, ß)
- **Format-Standard**: LaTeX → PDF, Markdown nur als Ausnahme
- **Ausgabepfad**: `sum/Zusammenfassung{Nr}.tex` / `.md`
- **Quellen-Pflicht**: Immer Aufgabenblatt, Musterlösung und Skript lesen — nie nur aus einer Quelle arbeiten
- **Context7**: Maximal 3 Aufrufe pro Zusammenfassung, nur bei konkretem Bedarf (LaTeX-Paket-Syntax, unbekannte Befehle)
- **tlmgr**: Ohne `sudo` aufrufen; bei Berechtigungsfehler den User bitten
- **Iterationslimit**: Maximal 3 Kompilier-/Prüf-Zyklen
- **tcolorbox vermeiden**: `mdframed` statt `tcolorbox` verwenden (Tagging-Bug in LaTeX 2024+)

---

## Skill-Optimierung

Nach Abschluss dieses Skills kurz bewerten, ob Optimierungsbedarf besteht:

- **Empfehlung "ja"**: Fehler aufgetreten, Workarounds nötig, Befehle wiederholt, User-Korrekturen
- **Empfehlung "nein"**: Reibungsloser Lauf wie dokumentiert

Per `AskUserQuestion` fragen:

> Skill abgeschlossen. Soll die Skill-Dokumentation optimiert werden?
> Empfehlung: {ja — [kurzer Grund] | nein — Lauf war reibungslos}

Optionen: **"Ja, optimieren"**, **"Nein"**

Bei "Ja": `skill-optimize` mit Skill-Name `lernzusammenfassung` ausführen.

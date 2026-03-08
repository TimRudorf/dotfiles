---
name: uni-study-summary
description: This skill should be used when the user asks to create a learning summary,
  Lernzusammenfassung, or Zusammenfassung for a Uebungsblatt or exercise sheet.
  It reads the exercise PDF, solution PDF, and lecture notes, then writes a structured
  LaTeX PDF (or Markdown) summary with theory, step-by-step recipes, and exam tips.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, Agent, mcp__context7__resolve-library-id, mcp__context7__query-docs
argument-hint: "[Übungsnummer, z.B. 03]"
disable-model-invocation: true
---

# Lernzusammenfassung erstellen

Erstellt eine strukturierte Lernzusammenfassung zu einem Übungsblatt. Der Benutzer gibt die Übungsnummer (z.B. `03`) über `$ARGUMENTS` — falls nicht gegeben, danach fragen.

## Schritt 1: Projektstruktur erkennen

1. Lies die `CLAUDE.md` im aktuellen Projektverzeichnis, um die Verzeichnisstruktur und das Fach zu verstehen. **Prüfe insbesondere, ob eine Sektion `## Skill-Anpassungen` → `### uni-study-summary` existiert.** Falls ja, gelten die dort definierten Overrides für Quellenstruktur, Fokus, Ausschlüsse und Abschnitt-Anpassungen für diesen gesamten Lauf.
2. Identifiziere anhand der CLAUDE.md (Dateitypen-Tabelle und Themenindex):
   - Das Aufgabenblatt: `docs/Übungen/Aufgaben/Übung-{Nr}.pdf`
   - Die Musterlösung: `docs/Übungen/Lösungen/Lösung-{Nr}.pdf`
   - Die Vorlesung: `docs/Vorlesung/Vorlesung-{Nr}.pdf` (oder `Vorlesung-Skript.pdf` bei Einzelskript)
   - Zusatzmaterial: `docs/Übungen/Weiteres/` und `docs/Zusatz/`
   - **Fallback** (alte Konvention): `docs/Skript/`, `docs/Sonstiges/`, `Aufgaben{Nr}.pdf`, `Loesungen{Nr}.pdf`
3. Falls Dateien nicht am erwarteten Ort liegen, suche mit Glob nach passenden Dateien.

## Schritt 2: Inhalte extrahieren (Context-optimiert)

Die Quell-PDFs werden **nicht** direkt im Main-Context gelesen. Stattdessen werden strukturierte Extrakte erstellt, die nur die klausurrelevanten Informationen enthalten. Der Main-Agent entscheidet autonom, ob er die Extraktion an Subagents (Task-Tool) delegiert oder selbst durchführt.

### Phase A — Aufgaben + Lösungen

**Quellen:** Übung-{Nr}.pdf + Lösung-{Nr}.pdf (bzw. bei Skill-Anpassungen die dort definierte Quellenstruktur; bei fehlenden separaten PDFs das relevante Skript-Kapitel mit eingebetteten Aufgaben).

**Extrahieren:**
- Aufgabenstellungen (kompakt, vollständig)
- Verwendete Methoden und Lösungsschritte
- Alle Formeln exakt in LaTeX-Notation
- Ergebnisse (Zahlenwerte, Ausdrücke)
- Fehlerhinweise und Besonderheiten aus der Musterlösung

**Weglassen:** Layout, Kopfzeilen, Seitennummern, redundante Standardformulierungen.

**Rückgabeformat (JSON):**
```json
{
  "themen": ["Thema 1", "Thema 2"],
  "skript_stichworte": ["Stichwort für Vorlesungszuordnung", "..."],
  "aufgaben": [
    {
      "nr": "1a",
      "aufgabe": "Kompakte Aufgabenstellung",
      "methode": "Verwendete Methode",
      "schritte": ["Schritt 1", "Schritt 2"],
      "formeln": ["\\LaTeX-Formel"],
      "ergebnis": "Endergebnis",
      "fehlerhinweise": ["Typischer Fehler"]
    }
  ]
}
```

### Phase B — Vorlesungstheorie (abhängig von Phase A)

**Quellen:** Relevante Vorlesungskapitel (ermittelt über Themenindex in CLAUDE.md + `skript_stichworte` aus Phase A), Zusatzmaterial aus `docs/Übungen/Weiteres/` und `docs/Zusatz/`.

**Extrahieren:**
- Definitionen und Sätze (exakter Wortlaut + LaTeX-Formeln)
- Methodenschritte und Algorithmen
- Voraussetzungen und Anwendbarkeitsbedingungen
- Zusammenhänge zwischen Konzepten
- Vorhandene Kochrezepte aus Zusatzmaterial

**Weglassen:** Historische Einordnungen, nicht-klausurrelevante Beweise, bereits durch Aufgaben abgedeckte Beispiele.

**Rückgabeformat (JSON):**
```json
{
  "definitionen": [
    {"name": "Name", "inhalt": "Exakter Wortlaut", "formel": "\\LaTeX"}
  ],
  "methoden": [
    {"name": "Methode", "schritte": ["Schritt 1", "..."], "voraussetzungen": "..."}
  ],
  "zusammenhaenge": "Freitext: Wie hängen die Konzepte zusammen?",
  "zusatzmaterial_kochrezepte": ["Kochrezept-Inhalt falls vorhanden"],
  "klausur_hinweise": ["Relevante Hinweise"]
}
```

## Schritt 3: Formatentscheidung

Standard ist **LaTeX → PDF** (`sum/Zusammenfassung{Nr}.pdf`). Markdown (`sum/Zusammenfassung{Nr}.md`) nur bei reinen Text-Zusammenfassungen ohne nennenswerte Formeln.

## Schritt 4: Zusammenfassung erstellen

Erstelle die Zusammenfassung auf **Deutsch** basierend auf den strukturierten Extrakten aus Schritt 2 — kein erneutes Lesen der Quell-PDFs nötig. Folgende Abschnitte:

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
1. Erstelle die LaTeX-Datei `sum/Zusammenfassung{Nr}.tex`. Lies `reference.md` (im Skill-Verzeichnis) für die vollständige Preamble, Farb-Definitionen und mdframed-Umgebungen. **Verwende ausschließlich die in `reference.md` gelisteten Pakete.** Falls ein zusätzliches Paket die Qualität verbessern würde, den User bitten es zu installieren — Qualität steht an erster Stelle.

> **Wichtig:** Verwende **nicht** `tcolorbox` — Tagging-Inkompatibilität mit dem LaTeX 2024+ Kernel erzeugt Debug-Output auf Seite 1.

2. Kompiliere mit `pdflatex`:
   ```bash
   pdflatex -interaction=nonstopmode -output-directory="<sum-Verzeichnis>" "<tex-Datei>"
   ```
   Falls `pdflatex` nicht im PATH: absoluten Pfad ermitteln (`which pdflatex` oder plattformspezifisch, z.B. `/Library/TeX/texbin/pdflatex` auf macOS).
   Zweimal ausführen für korrekte Referenzen.
3. Räume Hilfsdateien auf (`.aux`, `.log`, `.out`, `.toc`), behalte aber die `.tex`-Datei.
4. Falls die Kompilierung fehlschlägt, analysiere die `.log`-Datei:
   - **Fehlendes Paket** (`File '...' not found`): **Immer den User bitten** das Paket zu installieren (`tlmgr install <paketname>`). Niemals das Paket eigenmächtig entfernen oder die .tex-Datei umschreiben um das Paket zu umgehen.
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
- **Quellen-Pflicht**: Immer Aufgabenblatt, Musterlösung und Skript lesen — nie nur aus einer Quelle arbeiten. Falls Skill-Anpassungen eine abweichende Quellenstruktur definieren, dieser folgen.
- **Context7**: Maximal 3 Aufrufe pro Zusammenfassung, nur bei konkretem Bedarf (LaTeX-Paket-Syntax, unbekannte Befehle)
- **tlmgr**: Ohne `sudo` aufrufen; bei Berechtigungsfehler den User bitten
- **Iterationslimit**: Maximal 3 Kompilier-/Prüf-Zyklen
- **tcolorbox vermeiden**: `mdframed` statt `tcolorbox` verwenden (Tagging-Bug in LaTeX 2024+)

Abschließend `skill-optimize` mit `uni-study-summary` aufrufen.

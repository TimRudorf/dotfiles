---
name: eifert-doc
description: "Generates professional PDF documents using LaTeX with the Eifert Systems GmbH corporate template. Use when the user asks to create documents, reports, documentation, PDFs, or written deliverables in the context of Eifert Systems GmbH, Einsatzleitsoftware, edp:, or internal company documentation. Trigger keywords: Dokument, document, PDF, Report, Bericht, Dokumentation, LaTeX, erstellen, zusammenstellen."
disable-model-invocation: true
argument-hint: [Titel oder Beschreibung des Dokuments]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch
---

# Eifert Systems GmbH — Dokument erstellen

Erstellt professionelle PDF-Dokumente mit dem Eifert-Systems-LaTeX-Template via Docker.

## Voraussetzungen
- Tools: `docker`
- Datei: `~/.claude/skills/eifert-doc/eifert-internal.cls`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Schritt 1: Docker-Image sicherstellen

Prüfen ob `texlive/texlive:latest-small` lokal vorhanden ist:

```bash
docker image inspect texlive/texlive:latest-small >/dev/null 2>&1 || docker pull texlive/texlive:latest-small
```

## Schritt 2: Inhalt vorbereiten

Aus `$ARGUMENTS` und dem Gesprächskontext den Dokumentinhalt ableiten:
- Titel, Untertitel, Autor, Abteilung, Version
- Inhaltliche Gliederung (Sections, Subsections)
- Daten aus vorherigen Recherchen oder Abfragen einbeziehen

## Schritt 3: LaTeX-Dokument schreiben

Build-Verzeichnis anlegen und `.tex`-Datei erstellen:

```bash
mkdir -p /tmp/eifert-doc-build
cp ~/.claude/skills/eifert-doc/eifert-internal.cls /tmp/eifert-doc-build/
```

Die `.tex`-Datei nach `/tmp/eifert-doc-build/{dateiname}.tex` schreiben.

### Template-Verwendung

```latex
\documentclass{eifert-internal}

\title{Dokumenttitel}
\subtitle{Optionaler Untertitel}        % optional
\author{Name des Autors}
\date{Datum}
\department{Abteilung}                  % optional
\docversion{1.0}                        % optional
\classification{INTERN}                 % INTERN (default), VERTRAULICH, etc.

\begin{document}
\maketitle
\tableofcontents
\newpage

\section{...}
...
\end{document}
```

### Verfügbare Elemente

| Element | Verwendung |
|---------|-----------|
| `\section`, `\subsection`, `\subsubsection` | Überschriften (auto-formatiert mit Linien) |
| `longtable` + `booktabs` | Tabellen (`\toprule`, `\midrule`, `\bottomrule`) |
| `kompakt` (Environment) | Kompakte Aufzählungen mit Bullet Points |
| `kompaktenum` (Environment) | Kompakte nummerierte Listen |
| `hinweis` (Environment) | Hervorgehobene Hinweis-Box |
| `tabularx` | Tabellen mit automatischer Spaltenbreite |

### LaTeX-Hinweise

- Sonderzeichen escapen: `_` → `\_`, `%` → `\%`, `&` → `\&`, `#` → `\#`, `{` → `\{`, `}` → `\}`
- URLs in `\texttt{}` oder `\url{}` wrappen
- Für `>` und `<` in Text: `\textgreater{}` und `\textless{}`
- Deutsche Anführungszeichen: `` \glqq{}Text\grqq{} `` oder einfach „Text" direkt (UTF-8)

## Schritt 4: PDF kompilieren

Zwei Durchläufe (für Inhaltsverzeichnis und Seitenreferenzen):

```bash
docker run --rm -v /tmp/eifert-doc-build:/data texlive/texlive:latest-small sh -c "\
  tlmgr install titlesec enumitem lastpage 2>/dev/null; \
  cd /data && \
  pdflatex -interaction=nonstopmode {dateiname}.tex && \
  pdflatex -interaction=nonstopmode {dateiname}.tex"
```

Bei Fehlern: LaTeX-Log analysieren (`/tmp/eifert-doc-build/{dateiname}.log`), Fehler beheben, erneut kompilieren.

## Schritt 5: PDF ausliefern

Das fertige PDF per Telegram an den User senden:

```bash
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
  -F chat_id="${TELEGRAM_CHAT_ID}" \
  -F document=@"/tmp/eifert-doc-build/{dateiname}.pdf" \
  -F caption="📄 {Dokumenttitel}"
```

Optional: Persistente Kopie in `~/data/documents/` speichern wenn der User es wünscht.

## Schritt 6: Aufräumen

Dem User das Ergebnis bestätigen (Seitenanzahl, Dateigröße). Build-Verzeichnis kann bestehen bleiben für eventuelle Nachbearbeitung.

Abschließend `skill-optimize` mit `eifert-doc` aufrufen.

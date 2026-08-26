---
name: edp-latex-doc
description: Erstellt ein neues LaTeX-Dokument im edp-Hausstil — Bericht, Memo, Code-Briefing, Messe-Update oder formaler Brief. Klont/aktualisiert das edp-latex-Repo (GHE), kopiert das passende Template, klärt mit Tim Inhalt und Metadata, kompiliert lokal, öffnet PR auf dev und beobachtet CI bis grün. Trigger-Keywords - "edp-latex", "edp doc", "neues edp-dokument", "memo edp", "bericht für die arbeit", "code-briefing", "messe-update", "brief für edp", "latex für die arbeit", "/edp-latex-doc".
disable-model-invocation: true
---

# EDP LaTeX-Dokument erstellen

Workflow zum Anlegen, Kompilieren und Mergen eines neuen LaTeX-Dokuments im edp-Hausstil. Vollarchitektur des Repos siehe `$VAULT/projekte/edp-latex/architektur.md`.

## Voraussetzungen

- Env: `GH_WORK_HOST`, `GH_WORK_TOKEN`
- Tools: `tectonic`, `gh`, `git`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Schritt 1: Eckdaten mit Tim klären

Falls nicht aus dem Prompt ableitbar, Tim nacheinander fragen:

1. **Doc-Typ** — eine von vier Vorlagen wählen:
   - `bericht` → strukturierter Bericht (mehrere Sektionen, Empfehlung)
   - `memo` → kurzer Hinweis, eine Seite, ein Thema
   - `codebriefing` → Code-Refactor erklären, mit `\begin{lstlisting}`-Schnipseln
   - `brief` → formaler Brief an externen Empfänger (DIN 5008)
2. **Klassifizierung** (nur bei `bericht`/`memo`/`codebriefing`):
   - `intern` → Footer = Doc-Titel + Seitenzahl
   - `extern` → Footer = Legal-Zeile (default, wenn Außenwirkung)
3. **Titel** — pflicht. Bei `bericht` zusätzlich optionale **Subtitle**.
4. **Author** — default Tims voller Name.
5. **Datum** — default heute.
6. Bei `brief`: **Empfängeradresse** (mehrzeilig), **Betreff**, **Anrede**, **Schluss**.

Tim antwortet meist kompakt. Aus Antwort den **Slug** ableiten: kebab-case, ASCII, max ~50 Zeichen.

## Schritt 2: Repo-Working-Copy sicherstellen

Pfad ist hostabhängig:
- Container: `/workspace/edp-latex`
- Mac: `~/Documents/edp-latex` (falls dort nicht vorhanden, Tim fragen wo er es ablegen will)

Logik:
- Wenn Verzeichnis nicht existiert → klonen via HTTPS+Token: `git clone "https://x-access-token:${GH_WORK_TOKEN}@${GH_WORK_HOST}/edp/edp-latex.git" <pfad>`. Danach Remote-URL ohne Token setzen: `git remote set-url origin "https://${GH_WORK_HOST}/edp/edp-latex.git"`.
- Wenn vorhanden → `git switch dev && git pull` (Token-URL temporär setzen, danach zurück). Working-Copy muss clean sein, sonst Tim fragen.

## Schritt 3: Datei aus Template kopieren

Datum heute via `date +%Y-%m-%d`. Zielpfad: `dokumente/<jahr>/<datum>-<slug>.tex`. Verzeichnis ggf. mit `mkdir -p` anlegen.

Template-Mapping:

| Doc-Typ | Quelle |
|---|---|
| bericht | `examples/beispiel-bericht.tex` |
| memo | `examples/beispiel-memo.tex` |
| codebriefing | `examples/beispiel-codebriefing.tex` |
| brief | `examples/beispiel-brief.tex` |

Mit `cp` kopieren, dann Frontmatter (`\edpTitle`, `\edpSubtitle`, `\edpAuthor`, `\edpDate`) befüllen und Klassifizierungs-Option setzen (`\documentclass[intern]{edp-doc}` bzw. ohne Argument für `extern`).

## Schritt 4: Inhalt iterativ mit Tim erstellen

Beispielinhalt aus dem Template restlos rauswerfen — keine Lorem-Ipsum-Reste committen. Mit Tim die echten Sektionen/Absätze ausarbeiten. Bei `codebriefing` Code-Schnipsel von Tim erfragen oder aus Repo-Diff übernehmen — `\begin{lstlisting}[language={}]…\end{lstlisting}` für nicht-syntaxhighlighted Blöcke, sonst `[language=Pascal]` etc.

Nicht über die `\edpwordmark`/Logo-Macros nachdenken — die kommen aus der Klasse.

## Schritt 5: Lokal kompilieren und Output zeigen

Aus dem Repo-Root:

```sh
./build.sh dokumente/<jahr>/<datum>-<slug>.tex
```

`./build.sh` ist der Wrapper; `tectonic file.tex` direkt funktioniert NICHT (findet die Klassen nicht).

Bei Build-Fehler: Log lesen (`*.log` neben der `.tex`), Ursache fixen, retry. Häufige Fehler: fehlende Pakete (Tectonic lädt nach, einmal warten), Encoding-Probleme (sicherstellen UTF-8), unbalanced Klammern.

Bei Erfolg: PDF-Pfad an Tim melden — er entscheidet, ob er ihn vor dem PR ansehen will.

## Schritt 6: Feature-Branch + PR + Merge

Direct-Push auf `dev` ist vom GHE-Ruleset blockiert. IMMER über Feature-Branch + PR.

```sh
BRANCH="feat/<datum>-<slug>"
git switch -c "$BRANCH"
git add dokumente/<jahr>/<datum>-<slug>.tex
git commit -m "<Doc-Typ>: <Titel>"

# Push via Token-URL, danach zurück auf saubere URL
git remote set-url origin "https://x-access-token:${GH_WORK_TOKEN}@${GH_WORK_HOST}/edp/edp-latex.git"
git push -u origin "$BRANCH"
git remote set-url origin "https://${GH_WORK_HOST}/edp/edp-latex.git"
```

PR öffnen und mergen:

```sh
GH_HOST="$GH_WORK_HOST" GH_TOKEN="$GH_WORK_TOKEN" gh pr create \
  --repo edp/edp-latex --base dev --head "$BRANCH" \
  --title "<Doc-Typ>: <Titel>" \
  --body "Neues Dokument: <Titel> (<datum>)"

GH_HOST="$GH_WORK_HOST" GH_TOKEN="$GH_WORK_TOKEN" gh pr merge \
  --repo edp/edp-latex <pr-nr> --merge --delete-branch
```

Lokal nach Merge: `git switch dev && git pull` (Token-URL temporär setzen).

## Schritt 7: CI-Run beobachten

Nach Merge wird die `build`-Action getriggert. Universal-Regel `ci-nach-push-beobachten`: Status abwarten und beobachten.

```sh
GH_HOST="$GH_WORK_HOST" GH_TOKEN="$GH_WORK_TOKEN" gh run list \
  --repo edp/edp-latex --limit 1 \
  --json status,conclusion,workflowName,headSha,url
```

Wenn `status` noch nicht `completed`: 60–120 Sekunden warten (Wakeup), dann nochmal prüfen. Bei `conclusion=failure`: Log ziehen mit `gh run view <id> --log-failed`, Fehler fixen, neuen Feature-Branch + PR.

## Schritt 8: Tim final melden

Kurze Zusammenfassung an Tim:
- PDF-Pfad lokal
- PR-URL + Merge-Status
- CI-Run-URL + Conclusion
- Run-Artefakt enthält die kompilierten PDFs (30 Tage)

Abschließend `skill-optimize` mit `edp-latex-doc` aufrufen.

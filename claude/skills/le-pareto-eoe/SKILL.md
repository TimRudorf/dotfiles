---
name: le-pareto-eoe
description: Erzeugt aus einer eoe-Lerneinheit (Modul Modern Firm, Part B / Rode — Entrepreneurship) eine minimale, klausur-fokussierte Paper-Übersicht. Pro Paper genau drei Felder auf Deutsch (mit englischen Fachbegriffen in Klammern) — Was wurde untersucht? · Findings · Limitations (stichpunktartig). Nach Klausur-Relevanz sortiert. Bewusst knapper als das generische le-pareto oder eine 4-Achsen-Karte. Use when Tim das Klausur-Minimum, die Kernpunkte oder „was muss ich zum Bestehen können" einer eoe-Einheit (Modern Firm Part B) übersichtlich und schnell haben will. Trigger keywords - "Pareto für die eoe-LE", "Klausur-Minimum eoe", "was muss ich für Modern Firm Part B können", "le-pareto-eoe", "/le-pareto-eoe".
argument-hint: [eoe-einheit-id | LE-Text | Datei-Pfad]
---

# eoe-Lerneinheit — minimale Paper-Übersicht (Klausur-Minimum)

Erzeugt aus einer **eoe-Lerneinheit** (Modul *Modern Firm*, **Part B** / Rode — Entrepreneurship) eine bewusst **minimale** Klausur-Übersicht: pro Paper genau drei Felder. Zielperson: Tim, kurz vor der Klausur, wenig Zeit.

**Kern-Mehrwert gegenüber `le-pareto`:** maximal knapp und paper-strukturiert. Kein Fließtext, keine 4-Achsen-Tiefe, keine Eselsbrücken-Deko — nur *Was wurde untersucht? · Findings · Limitations* je Paper, auf Deutsch mit englischen Fachbegriffen in Klammern (Klausursprache EN).

## Schritt 1: LE + Content-PDF beschaffen

Die eoe-Einheit kann übergeben werden als:

- **eoe-`einheit-id`** (Muster `eoe-NN-slug`, z.B. `eoe-04-labor-markets`): direkt `$VAULT/projekte/lernplan/modern-firm/lerneinheiten/$ARGUMENTS.md` lesen.
- **Datei-Pfad / Inline-Text**: entsprechend Datei lesen bzw. Text direkt nutzen.

Vault-Root host-abhängig (Mac: `~/Documents/jarvis-wiki/`, Container: `/workspace/wiki/`) — den existierenden als `$VAULT` merken.

**Content-als-PDF-Pattern (bei eoe fast immer):** Der eigentliche Stoff steht NICHT im Markdown, sondern im verlinkten Content-PDF (Frontmatter `le-pdf` / `le-pdf-de`, Callout „Content-PDF"). Zwingend das PDF lesen — das **englische** `le-pdf` (Klausursprache EN), damit die Fachbegriffe stimmen. Bei umfangreichen PDFs vollständig lesen (`plan-quellen-tiefenanalyse`).

## Schritt 2: Relevanz-Sortierung (leichtgewichtig)

`$VAULT/projekte/lernplan/modern-firm/mock-frageformen.md` lesen, nur um die Paper zu **sortieren**: mock-belegte + *starred* Paper zuerst, reine Distraktor-/unbelegte Paper ganz ans Ende (dort genügt ein Einzeiler). Mehr wird daraus nicht gebraucht — keine Frageform-Aufspaltung.

## Schritt 3: Pro Paper drei Felder füllen

Für jedes relevante Paper aus dem Content-PDF genau diese drei Punkte destillieren:

1. **Was wurde untersucht?** — Forschungsfrage + kurz Daten/Modell (**research question**, welche Methode/Sample).
2. **Findings** — die Kernergebnisse mit den echten Zahlen, verbatim aus dem PDF.
3. **Limitations** — stichpunktartig, die 2–3 wichtigsten (**threats to validity**).

Deutsch formulieren, die stehenden Fachbegriffe in Klammern auf Englisch mitführen (z.B. „Ausgründungen (spawning)", „risikokapital-finanziert (VC-backed)", „nicht kausal (correlation only)"), weil Tim sie in der EN-Klausur so abrufen muss. Nichts erfinden — nur was im PDF steht.

## Schritt 4: Ausgabe

Gib das Ergebnis in **genau dieser Struktur** aus — knapp, scanbar, ein Block je Paper, nach Relevanz sortiert:

```markdown
# 🎯 <eoe-NN · Topic-Titel> — Klausur-Minimum (Part B)

> 🧭 <1 Satz roter Faden des Topics.> · Klausursprache **EN**.

---

## <Paper A> (<Journal Jahr>)

**Was wurde untersucht?**
<1–3 Sätze: Forschungsfrage + Daten/Modell, DE mit EN-Begriffen in Klammern.>

**Findings**
<1–3 Sätze / Bullets mit den echten Zahlen.>

**Limitations**
- <Stichpunkt>
- <Stichpunkt>

---

## <Paper B> (<Journal Jahr>)

**Was wurde untersucht?**
…

**Findings**
…

**Limitations**
- …

---

## Nebenrolle (nur erkennen)
- **<Paper C> (<Jahr>):** <ein Satz.>
```

Regeln:
- **Nur die drei Felder** pro Paper — nichts dazwischen, keine Mechanismus-Achse, keine Merksätze, keine Landkarten-Tabelle. Genau so knapp halten.
- **Nach Relevanz sortiert** (wichtigste Paper oben), Distraktor-Paper als „Nebenrolle" mit einem Satz.
- **Deutsch + EN-Fachbegriffe in Klammern** durchgängig.
- **Treu zur Quelle** — Inhalt strikt aus dem Content-PDF, nichts erfinden, keine Zahl raten.

Abschließend `skill-optimize` mit `le-pareto-eoe` aufrufen.

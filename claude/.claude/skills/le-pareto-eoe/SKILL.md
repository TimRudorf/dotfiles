---
name: le-pareto-eoe
description: Erzeugt aus einer eoe-Lerneinheit (Modul Modern Firm, Part B / Rode — Entrepreneurship) eine kurze, leicht verständliche Paper-Übersicht fürs Klausur-Minimum. Pro Paper ein knapper Block in Alltagssprache (Frage · Antwort · ggf. Der Trick · Haken · ggf. Falle), deutsch formuliert mit den englischen Fachbegriffen in Klammern, weil die Klausur EN ist. Nach Klausur-Relevanz sortiert. Bewusst knapper und einfacher als das generische le-pareto oder eine 4-Achsen-Karte. Use when Tim das Klausur-Minimum, die Kernpunkte oder „was muss ich zum Bestehen können" einer eoe-Einheit (Modern Firm Part B) übersichtlich und schnell haben will. Trigger keywords - "Pareto für die eoe-LE", "Klausur-Minimum eoe", "was muss ich für Modern Firm Part B können", "le-pareto-eoe", "/le-pareto-eoe".
argument-hint: [eoe-einheit-id | LE-Text | Datei-Pfad]
---

# eoe-Lerneinheit — kurze Paper-Übersicht (Klausur-Minimum)

Erzeugt aus einer **eoe-Lerneinheit** (Modul *Modern Firm*, **Part B** / Rode — Entrepreneurship) eine bewusst **kurze und leicht verständliche** Klausur-Übersicht: pro Paper ein knapper Frage-/Antwort-Block. Zielperson: Tim, kurz vor der Klausur, wenig Zeit.

**Kern-Mehrwert gegenüber `le-pareto`:** maximal knapp, paper-strukturiert und in **Alltagssprache** — Tim soll es beim ersten Lesen verstehen, nicht entschlüsseln. Kein Fließtext-Essay, keine 4-Achsen-Tiefe, keine Deko. Die **englischen Fachbegriffe stehen in Klammern**, damit er denselben Inhalt in der EN-Klausur wiedergeben kann.

## Schritt 1: LE + Content-PDF beschaffen

Die eoe-Einheit kann übergeben werden als:

- **eoe-`einheit-id`** (Muster `eoe-NN-slug`, z.B. `eoe-04-labor-markets`): direkt `$VAULT/projekte/lernplan/modern-firm/lerneinheiten/$ARGUMENTS.md` lesen.
- **Datei-Pfad / Inline-Text**: entsprechend Datei lesen bzw. Text direkt nutzen.

Vault-Root host-abhängig (Mac: `~/Documents/jarvis-wiki/`, Container: `/workspace/wiki/`) — den existierenden als `$VAULT` merken.

**Content-als-PDF-Pattern (bei eoe fast immer):** Der eigentliche Stoff steht NICHT im Markdown, sondern im verlinkten Content-PDF (Frontmatter `le-pdf` / `le-pdf-de`, Callout „Content-PDF"). Zwingend das PDF lesen — das **englische** `le-pdf` (Klausursprache EN), damit die Fachbegriffe stimmen. Bei umfangreichen PDFs vollständig lesen (`plan-quellen-tiefenanalyse`).

## Schritt 2: Relevanz-Sortierung (leichtgewichtig)

`$VAULT/projekte/lernplan/modern-firm/mock-frageformen.md` lesen, nur um die Paper zu **sortieren**: mock-belegte + *starred* Paper zuerst, danach die supporting-Paper, ganz ans Ende die unbelegten (dort genügt ein Einzeiler unter „Nebenrolle"). Mehr wird daraus nicht gebraucht — keine Frageform-Aufspaltung.

**Supporting-Paper mit MC-Beleg bekommen einen vollen Block**, keinen Einzeiler — auch wenn die Mock-Tabelle sie als Distraktor führt (z.B. Baumol 1990: Distraktor *und* konzeptionelle Grundlage des Topics). „Nebenrolle" ist nur für Paper **ohne jeden Mock-Beleg**, etwa Rodes moderne Follow-ups.

## Schritt 3: Pro Paper den Block füllen

Für jedes relevante Paper aus dem Content-PDF diese Felder destillieren — **in Alltagssprache, als würdest du es jemandem erklären, der das Paper nie gesehen hat**:

1. **Frage** — die Forschungsfrage (**research question**) in 1–2 einfachen Sätzen. Kein Methoden-Jargon.
2. **Antwort** — der Kernbefund **mit den echten Zahlen**, verbatim aus dem PDF.
3. **Der Trick** *(nur wenn es einen gibt)* — die Identifikationsstrategie (**identification strategy**) in einem Satz: *warum* ist das kausal? Weglassen, wenn das Paper rein korrelativ oder anekdotisch ist.
4. **Haken** — die 1–3 wichtigsten Limitationen (**threats to validity**), knapp.
5. **⚠ Falle** *(nur wenn es eine gibt)* — die konkrete Klausurfalle: falscher Name, invertiertes Finding, verwechselter Begriff.

Deutsch formulieren, die stehenden Fachbegriffe in Klammern auf Englisch mitführen (z.B. „Talent-Allokation (allocation of talent)", „Ausgründungen (spawning)", „risikokapital-finanziert (VC-backed)", „nicht kausal (correlation only)") — Tim muss sie in der EN-Klausur so abrufen. Nichts erfinden — nur was im PDF steht.

## Schritt 4: Ausgabe

Gib das Ergebnis in **genau dieser Struktur** aus — kurz, scanbar, ein Block je Paper, nach Relevanz sortiert:

```markdown
# <eoe-NN · Topic-Titel> in Kurzform — was jedes Paper sagt

**Die eine Idee des Topics:** <1–2 Sätze roter Faden, in Alltagssprache.>

---

## <Autoren Jahr> — <Merk-Schlagzeile in Tims Worten>

**Frage:** <1–2 einfache Sätze.>

**Antwort:** <Kernbefund mit den echten Zahlen, die Zahlen fett.>

**Der Trick:** <1 Satz Identifikation — nur wenn kausal.>

**Haken:** <1–2 Sätze Limitationen.>

**⚠ Falle:** <nur wenn es eine gibt.>

---

## <Autoren Jahr> — <Merk-Schlagzeile>

**Frage:** …

**Antwort:** …

**Haken:** …

---

## Nebenrolle (nur erkennen)
- **<Paper> (<Jahr>):** <ein Satz.>

---

**Die Kette in einem Satz:** <alle Paper des Topics als eine Erzählung verbunden.>
```

Regeln:
- **Leicht verständlich schlägt vollständig.** Kurze Sätze, Alltagssprache, keine Schachtelsätze. Wenn ein Satz zweimal gelesen werden muss, umschreiben.
- **Nur die genannten Felder** — nichts dazwischen, keine Mechanismus-Achse, keine Landkarten-Tabelle. „Der Trick" und „⚠ Falle" nur, wenn inhaltlich vorhanden.
- **Merk-Schlagzeile pro Paper** — ein einprägsamer Halbsatz statt nur „Autor Jahr" (z.B. „engineers good, lawyers bad", „nimm dem Erfinder das Patent, und er erfindet nicht mehr").
- **Zahlen immer mit** — die Magnituden sind der Punkte-Träger in Part B; nie „signifikant positiv" schreiben, wo die echte Zahl im PDF steht.
- **Deutsch + EN-Fachbegriffe in Klammern** durchgängig.
- **Kette am Ende** — ein Satz, der alle Paper des Topics zu Rodes Erzählbogen verbindet.
- **Treu zur Quelle** — Inhalt strikt aus dem Content-PDF, nichts erfinden, keine Zahl raten.

Abschließend `skill-optimize` mit `le-pareto-eoe` aufrufen.

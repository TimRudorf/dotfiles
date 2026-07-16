---
name: le-pareto-eoe
description: Erzeugt aus einer eoe-Lerneinheit (Modul Modern Firm, Part B / Rode — Entrepreneurship) das klausur-priorisierte Muss-Minimum nach Pareto (20/80), zugeschnitten auf die Paper-Struktur des Moduls. Anders als das generische le-pareto stellt dieser Skill den Stoff paper-für-paper als einheitliche, scanbare 4-Achsen-Karte dar (Forschungsfrage+ID · Findings+Magnitude · Mechanismus · 2 Limitationen), mit einer Topic-Landkarte vorweg und nach Klausur-Relevanz sortiert. Use when Tim das Klausur-Minimum, die Pareto-Punkte oder „was muss ich zum Bestehen können" einer eoe-Einheit (Modern Firm Part B) übersichtlich haben will. Trigger keywords - "Pareto für die eoe-LE", "Klausur-Minimum eoe", "was muss ich für Modern Firm Part B können", "le-pareto-eoe", "/le-pareto-eoe".
argument-hint: [eoe-einheit-id | LE-Text | Datei-Pfad]
---

# eoe-Lerneinheit — Pareto-Klausurminimum (paper-strukturiert)

Erzeugt aus einer **eoe-Lerneinheit** (Modul *Modern Firm*, **Part B** / Rode — Entrepreneurship) das **Muss-Minimum für die Klausur** nach Pareto: die ~20 % Inhalt, die ~80 % der Punkte bringen. Zugeschnitten auf die Modul-Realität — **Part B besteht aus Paper-Fragen**, jedes Topic bündelt mehrere Paper. Zielperson: Tim, kurz vor der Klausur.

**Kern-Mehrwert gegenüber `le-pareto`:** Die Darstellung ist **paper-optimiert und übersichtlich** — eine Topic-Landkarte vorweg, dann pro Paper eine *einheitliche, immer gleich aufgebaute* 4-Achsen-Karte. Man scannt statt zu lesen; jedes Paper sieht gleich aus, also findet man schnell die Achse, die man braucht.

## Schritt 1: LE + Content-PDF beschaffen

Die eoe-Einheit kann übergeben werden als:

- **eoe-`einheit-id`** (Muster `eoe-NN-slug`, z.B. `eoe-04-labor-markets`): direkt `$VAULT/projekte/lernplan/modern-firm/lerneinheiten/$ARGUMENTS.md` lesen.
- **Datei-Pfad / Inline-Text**: entsprechend Datei lesen bzw. Text direkt nutzen.

Vault-Root host-abhängig (Mac: `~/Documents/jarvis-wiki/`, Container: `/workspace/wiki/`) — den existierenden als `$VAULT` merken.

**Content-als-PDF-Pattern (bei eoe fast immer):** Der eigentliche Stoff steht NICHT im Markdown, sondern im verlinkten Content-PDF (Frontmatter `le-pdf` / `le-pdf-de`, Callout „Content-PDF"). Zwingend das PDF lesen. **Sprachwahl = Klausursprache:** eoe ist `klausur-sprache: EN` → das **englische** `le-pdf` lesen (nur bei Verständnisbedarf zusätzlich `le-pdf-de`). Tim muss die Fachbegriffe englisch abrufen können.

Bei umfangreichen PDFs den **vollständigen** Inhalt lesen (`plan-quellen-tiefenanalyse`), nicht nur den Anfang.

## Schritt 2: Klausur-Relevanz je Paper bestimmen (nur zur Priorisierung)

`$VAULT/projekte/lernplan/modern-firm/mock-frageformen.md` lesen — die Ground-Truth aus allen 7 echten Mock-Klausuren. **Nur zwei Dinge** daraus ziehen, rein zur Sortierung/Gewichtung der Paper (nicht um die Darstellung nach Frageform aufzuspalten):

- **Welche Paper der LE sind klausur-belegt** (in einem echten Mock aufgetaucht) bzw. *starred* → diese kommen als volle Karten, oben.
- **Welche Paper sind nur Distraktoren / unbelegt** → gebündelt ans Ende, minimal.

Die Frageform (MC vs. Long) ist für die Darstellung **nachrangig** — sie darf höchstens als kleines Label an der Karte stehen, steuert aber nicht den Detailgrad. Jedes relevante Paper bekommt die gleiche 4-Achsen-Karte.

> ⚠️ Datenbasis-Vorbehalt (einmal knapp im Output nennen): Part B war nur in **2 von 7** Mocks ausgefüllt (Winter 24/25 + Summer 24), keine Musterlösungen. „Nicht im Mock gesehen" ≠ „kommt nicht dran".

## Schritt 3: Die 4 Achsen als einheitliches Karten-Raster

Rode prüft jedes Paper entlang **4 Achsen**. Diese vier sind das feste Gerüst jeder Paper-Karte — immer in dieser Reihenfolge, damit alle Karten gleich aussehen:

1. **Forschungsfrage + Identifikation** — welche Frage, welche Daten/welches Modell, und **„is it causal?"** (bei Empirik-Papern meist *nein* → reine Korrelation, Rodes Dauer-Trap).
2. **Findings + Magnitude** — die echten Zahlen (Richtung *und* Größenordnung), verbatim aus dem PDF.
3. **Mechanismus / Extra-Result** — warum der Effekt zustande kommt.
4. **2 Limitationen** — Rodes Standard-Block, oft „two criticisms".

Zusatz-Zeilen pro Karte nur wenn im PDF vorhanden:
- **⚠️ Falle** — der klassische Trap dieses Papers (invertierte Aussage, Zahlen-Verwechslung, Autor-Verwechslung wie AT94↔AT97).
- **📊 Tabelle** — wenn das Paper eine Regressionstabelle hat: sign → `|t|>2` → magnitude (`e^β−1`, nicht β) → ökonomisch vs. statistisch.
- **🔑 Merker** — eine Eselsbrücke, nur wenn sie trägt.

## Schritt 4: Priorisieren

Reihenfolge der Paper-Karten nach **Klausur-Relevanz** (aus Schritt 2): mock-belegte + starred Paper zuerst (untereinander egal ob MC oder Long), Companions/Distraktoren gebündelt ans Ende. Mut zur Lücke — unbelegte Sekundärpaper und Detailtiefe ohne Klausur-Anker kommen nicht als volle Karte.

## Schritt 5: Ausgabe — Topic-Landkarte + einheitliche Paper-Karten

Gib das Ergebnis in **genau dieser Struktur** aus (Deutsch als Erklärsprache, Fachbegriffe/abrufbare Antworten **englisch**, weil Klausursprache EN):

```markdown
# 🎯 <eoe-NN · Topic-Titel> — Klausur-Minimum (Part B, Pareto 20/80)

> 🧭 **Worum geht's:** <1–2 Sätze roter Faden des Topics in Alltagssprache.>

**Format:** Part B = MC + 2 Long-Essays. Kein Rechnen. Klausursprache **EN**. <Datenbasis-Vorbehalt in einem Halbsatz.>

## 🗺️ Landkarte — die Paper dieses Topics auf einen Blick

| # | Paper | Relevanz | Kernaussage in einem Satz |
|:-:|---|:--:|---|
| 1 | **<Paper A>** | 🥇 belegt | <the one-liner> |
| 2 | **<Paper B>** | 🥈 starred | <the one-liner> |
| 3 | **<Paper C>** | 📎 companion | <the one-liner> |

*Faustregel: Karten 1–2 sitzen müssen; Companions nur erkennen.*

---

## 1 · <Paper A> <Journal Jahr>   ·   🥇
> **In einem Satz:** <die eine Kernaussage, EN.>

| Achse | Inhalt |
|---|---|
| **① Frage + ID** | <Frage; Daten/Modell; **causal? ja/nein — warum**> |
| **② Findings + Magnitude** | <echte Zahlen, verbatim> |
| **③ Mechanismus** | <warum der Effekt> |
| **④ 2 Limitationen** | (1) <…> · (2) <…> |

⚠️ **Falle:** <der typische Trap.>
📊 **Tabelle:** <nur wenn Table-Paper.>
🔑 **Merker:** <nur wenn sie trägt.>

---

## 2 · <Paper B> <Journal Jahr>   ·   🥈
> **In einem Satz:** <…>

| Achse | Inhalt |
|---|---|
| **① Frage + ID** | <…> |
| **② Findings + Magnitude** | <…> |
| **③ Mechanismus** | <…> |
| **④ 2 Limitationen** | (1) <…> · (2) <…> |

⚠️ **Falle:** <…>

---

## 📎 Companions (nur erkennen, nicht ausformulieren)
- **<Paper C> <Jahr>:** <ein Erkennungssatz + womit es in MC verwechselt wird.>

---

### ✅ Self-Test (kurz vor der Klausur)
1. <prüft Paper 1, tiefste Achse>
2. <prüft Paper 2, Kernaussage + Falle>
3. <prüft einen Verwechslungs-Trap>

Wenn alle ja → Topic sitzt.
```

Regeln für die Ausgabe:
- **Landkarte zuerst, dann einheitliche Karten** — das ist der Kern-Mehrwert. Jede Paper-Karte hat *dieselbe* 4-Achsen-Tabelle in *derselben* Reihenfolge, sodass Tim quer über die Paper dieselbe Achse vergleichen kann.
- **Konsistenz vor Vollständigkeit** — lieber alle Karten gleich knapp als eine Karte ausufernd. Die Tabellenform zwingt zur Kürze pro Zelle (1–2 Sätze / Zahlen).
- **Nach Relevanz sortiert** (🥇 belegt → 🥈 starred → 📎 companion), nicht nach PDF-Reihenfolge.
- **Treu zur Quelle** — Inhalt strikt aus dem Content-PDF, Relevanz-Einstufung strikt aus mock-frageformen.md. Nichts erfinden, keine Zahl/Mock-Angabe raten.
- **Fachbegriffe/abrufbare Antworten EN**, Erklärungen drumherum deutsch.
- **Companions bewusst kurz** — ein Satz reicht.

Abschließend `skill-optimize` mit `le-pareto-eoe` aufrufen.

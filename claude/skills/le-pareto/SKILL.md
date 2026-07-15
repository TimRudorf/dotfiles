---
name: le-pareto
description: Erzeugt aus einer übergebenen Lerneinheit (LE) das klausur-priorisierte Muss-Minimum nach dem Pareto-Prinzip (20/80) — die ~20 % Stoff, die ~80 % der Punkte bringen, geordnet nach Punkte-Ertrag, mit Eselsbrücken und Self-Test. Anders als le-zusammenfassen (verständliche Volltext-Zusammenfassung) beantwortet dieser Skill nur „Was muss ich für die Klausur unbedingt können, um zu bestehen?". Use when Tim das Klausur-Minimum, die wichtigsten Punkte, den Pareto-Kern oder „was muss ich zum Bestehen können" einer LE haben will. Trigger keywords - "was muss ich für die Klausur können", "Pareto für die LE", "20/80 der LE", "Klausur-Minimum", "das Wichtigste zum Bestehen", "le-pareto", "/le-pareto".
argument-hint: [LE-Text | Datei-Pfad | Vault-Note | einheit-id]
---

# Lerneinheit — Pareto-Klausurminimum

Erzeugt aus der übergebenen Lerneinheit (LE) das **Muss-Minimum für die Klausur** nach dem Pareto-Prinzip: die ~20 % Inhalt, die ~80 % der Punkte bringen — priorisiert nach Punkte-Ertrag, nicht nach Vollständigkeit. Zielperson: Tim, kurz vor der Klausur, will effizient auf Bestehen lernen.

## Schritt 1: LE beschaffen

Die Lerneinheit kann auf mehreren Wegen übergeben werden — erkenne selbst, welcher Fall vorliegt:

- **Inline-Text**: Der LE-Inhalt steht direkt in `$ARGUMENTS`.
- **Datei-Pfad**: `$ARGUMENTS` ist ein Pfad (PDF, Folien, Markdown, Skript) → Datei lesen.
- **Vault-Note**: `$ARGUMENTS` verweist auf eine Note im jarvis-wiki → Note lesen. Vault-Root host-abhängig (Mac: `~/Documents/jarvis-wiki/`, Container: `/workspace/wiki/`).
  - **Ist `$ARGUMENTS` eine LE-`einheit-id`** (Muster `<modul-kürzel>-NN-slug`, z.B. `iti-04-market-entry-margins`): direkt `$VAULT/projekte/lernplan/*/lerneinheiten/$ARGUMENTS.md` lesen — kein vault-weites Grep nötig, der Modulordner ergibt sich aus dem Glob.
  - **Content-als-PDF-Pattern beachten:** Viele Lernplan-LE-Notes enthalten den eigentlichen Stoff NICHT im Markdown, sondern in einem verlinkten Content-PDF (Frontmatter `le-pdf-de` / `le-pdf`, Callout „Content-PDF"). Die Note liefert dann nur Lernziele, Ablauf und Anki-Karten. In diesem Fall zwingend das PDF lesen — das Klausur-Minimum muss auf dem PDF-Inhalt basieren, nicht auf der Note allein. **Sprachwahl des PDF = Modul-/Klausursprache:** Lies die Content-PDF-Fassung in der Sprache, in der das Modul geprüft wird (Detektor: Frontmatter `klausur-sprache`). Bei `klausur-sprache: EN` das englische `le-pdf`, bei DE (oder fehlendem Feld) `le-pdf-de` bzw. das einzige vorhandene PDF. So arbeitest du im Original-Vokabular, das Tim in der Klausur abrufen muss.
  - Bleibt die Note unauffindbar oder ist `$ARGUMENTS` kein id-Muster → `grep -ril` als Fallback, sonst kurz nachfragen.

Ist nichts übergeben oder unklar, welche LE gemeint ist: kurz nachfragen, welche Lerneinheit gemeint ist (Titel/Pfad/Text/id).

Bei umfangreichen Originalquellen (PDF/Folien): den **vollständigen** Inhalt lesen, nicht nur den Anfang — die Priorisierung muss die ganze LE überblicken (vgl. `plan-quellen-tiefenanalyse`).

## Schritt 2: Klausur-Signale ausfindig machen und priorisieren

Bevor du priorisierst, sammle die **Klausur-Relevanz-Signale** aus der Quelle — das ist der Kern dieses Skills. In LE-Notes und Content-PDFs sind sie meist explizit markiert:

- **Explizite Prüfungs-Hinweise**: Callouts/Sektionen wie „Exam", „🎯 Klausur-Frage", „Probe-2024-Frage", verbatim-Fragen, Punkte-Angaben (z.B. „(5)"). **Diese haben höchste Priorität** — was wörtlich in einer Probeklausur stand, kommt am ehesten wieder.
- **Lernziele** (Frontmatter/„Soll am Ende") — was das Modul selbst als Kernkompetenz definiert.
- **Anki-Karten-Plan** — die kalibrierte Auswahl dessen, was hängenbleiben muss; die Karten-Reihenfolge/-Tags signalisieren Wichtigkeit.
- **Typische Fallen / „don't conflate"-Hinweise** — subtile Unterscheidungen, die gern geprüft werden.

Ordne den gesamten Stoff dann in **3 Prioritätsstufen**:
1. **🥇/🥈/🥉 Muss (die ~20 %)** — ohne das fällt man durch bzw. verliert die meisten Punkte. Fast immer: die explizit als Prüfungsfrage markierten Inhalte + die 1–2 zentralen Mechanismen/Formeln + die klassische Falle.
2. **📎 Nice-to-have** — bringt Zusatzpunkte, aber nur wenn Zeit; NICHT bestehensentscheidend.
3. **Weglassen** — Detailtiefe, die für die Klausur irrelevant ist; taucht im Output gar nicht auf.

Halte die Muss-Ebene bewusst klein (Richtwert 3–4 Blöcke) — Pareto heißt Mut zur Lücke, kein zweites Skript.

## Schritt 3: Klausurminimum ausgeben

Gib das Ergebnis in **genau dieser Struktur** aus — scanbar, lernfreundlich, priorisiert. Die Muss-Blöcke nach Punkte-Ertrag absteigend (🥇 → 🥈 → 🥉).

```markdown
# 🎯 <Modul/LE-Kürzel> — Klausur-Minimum (Pareto 20/80)

Das sind die **~20 % Inhalt, die ~80 % der Punkte** bringen. Wenn du nur das kannst, bestehst du <diesen Topic / diese LE>.

---

## 🥇 MUSS-1: <der punkteträchtigste Inhalt>

> ⭐ **Warum zuerst:** <z.B. „Die wörtliche Probe-Frage (5 P.)" — die Klausur-Begründung, warum das oben steht.>

<Der Inhalt selbst — als nummerierte Liste, Kernsatz oder Mini-Tabelle. Bei fremdsprachiger Klausur: Fachbegriffe in der Klausursprache.>

**Eselsbrücke:** <Merkhilfe/Akronym, wenn sinnvoll.>

---

## 🥈 MUSS-2: <zweitwichtigster Inhalt> … (analog)

## 🥉 MUSS-3: <die klassische Falle / dritter Muss-Block> … (analog)

---

## 📎 Nice-to-have (nur wenn Zeit)
- <Zusatzpunkte-Inhalte als knappe Bullets — klar als nachrangig markiert.>

---

### ✅ Self-Test (kurz vor der Klausur)
1. <Frage, die MUSS-1 prüft — abrufbar?>
2. <Frage, die MUSS-2 prüft?>
3. <Frage, die die Falle aus MUSS-3 prüft — sicher richtig herum?>

Wenn 3× ja → <Topic/LE> sitzt.
```

Regeln für die Ausgabe:
- **Priorisierung ist der ganze Wert** — nicht alles gleich gewichten. Was die Quelle explizit als Prüfungsstoff markiert, steht ganz oben und wird als solches begründet („⭐ Warum zuerst").
- **Output IMMER auf Deutsch** — Erklärungen, Überschriften, Merksätze durchgehend deutsch, weil das die Verständnissprache ist.
- **Fremdsprachige Klausur → Fachbegriffe in der Klausursprache mitführen.** Ist das Modul nicht deutsch geprüft (Detektor: `klausur-sprache` ≠ DE, fremdsprachiges Content-PDF), muss Tim die Terme in der Klausursprache abrufen können — führe sie im Original mit (die abrufbare Antwort selbst ggf. komplett in der Klausursprache, wenn es eine Frei-Text-Frage ist).
- **Treu zur Quelle** — nichts erfinden, was nicht in der LE steht; keine Punkte-Angabe erfinden, wenn keine dasteht. Priorität aus echten Signalen ableiten, nicht raten.
- **Eselsbrücken nur wenn sie tragen** — ein erzwungenes Akronym ist schlechter als keins.
- **Knapp** — das ist ein Lern-Spickzettel, kein Skript-Ersatz. Im Zweifel weniger Muss-Blöcke, dafür klarer.

Abschließend `skill-optimize` mit `le-pareto` aufrufen.

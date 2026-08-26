---
name: le-zusammenfassen
description: Fasst eine übergebene Lerneinheit (LE) leicht verständlich und ohne vorausgesetztes Vorwissen zusammen — in drei Teilen: Worum geht es?, Kerninhalte leicht erklärt, Einordnung ins Modul. Use when Tim eine Lerneinheit, ein Skript, ein Kapitel oder einen Foliensatz zusammengefasst haben will. Trigger keywords - "fass die LE zusammen", "erklär mir die Lerneinheit", "worum geht es in dieser LE", "LE zusammenfassen", "leicht verständlich zusammenfassen", "/le-zusammenfassen".
argument-hint: [LE-Text | Datei-Pfad | Vault-Note]
---

# Lerneinheit zusammenfassen

Fasst die übergebene Lerneinheit (LE) leicht verständlich zusammen — **ohne jegliches Vorwissen vorauszusetzen**. Zielgruppe: jemand, der zum ersten Mal mit dem Thema in Berührung kommt.

## Schritt 1: LE beschaffen

Die Lerneinheit kann auf drei Wegen übergeben werden — erkenne selbst, welcher Fall vorliegt:

- **Inline-Text**: Der LE-Inhalt steht direkt in `$ARGUMENTS`.
- **Datei-Pfad**: `$ARGUMENTS` ist ein Pfad (PDF, Folien, Markdown, Skript) → Datei lesen.
- **Vault-Note**: `$ARGUMENTS` verweist auf eine Note im jarvis-wiki → Note lesen. Vault-Root host-abhängig (Mac: `~/Documents/jarvis-wiki/`, Container: `/workspace/wiki/`).
  - **Ist `$ARGUMENTS` eine LE-`einheit-id`** (Muster `<modul-kürzel>-NN-slug`, z.B. `mf-09-theory-of-firm`): direkt `$VAULT/projekte/lernplan/*/lerneinheiten/$ARGUMENTS.md` lesen — kein vault-weites Grep nötig, der Modulordner ergibt sich aus dem Glob.
  - **Content-als-PDF-Pattern beachten:** Viele Lernplan-LE-Notes enthalten den eigentlichen Stoff NICHT im Markdown, sondern in einem verlinkten Content-PDF (Frontmatter `le-pdf-de` / `le-pdf`, Callout „Content-PDF"). Die Note liefert dann nur Lernziele, Ablauf und Anki-Karten. In diesem Fall zwingend das PDF lesen — die Zusammenfassung muss auf dem PDF-Inhalt basieren, nicht auf der Note allein. **Sprachwahl des PDF = Modul-/Klausursprache:** Lies die Content-PDF-Fassung in der Sprache, in der das Modul unterrichtet/geprüft wird (Detektor: Frontmatter `klausur-sprache`). Bei `klausur-sprache: EN` das englische `le-pdf`, bei DE (oder fehlendem Feld) `le-pdf-de` bzw. das einzige vorhandene PDF. So arbeitest du im Original-Vokabular, das Tim in der Klausur abrufen muss — die Zusammenfassung selbst ist davon unabhängig immer deutsch (siehe Schritt 3).
  - Bleibt die Note unauffindbar oder ist `$ARGUMENTS` kein id-Muster → `grep -ril` als Fallback, sonst kurz nachfragen.

Ist nichts übergeben oder unklar, welche LE gemeint ist: kurz nachfragen, welche Lerneinheit zusammengefasst werden soll (Titel/Pfad/Text).

Bei umfangreichen Originalquellen (PDF/Folien): den **vollständigen** Inhalt lesen, nicht nur den Anfang — die Zusammenfassung muss die ganze LE abdecken (vgl. `plan-quellen-tiefenanalyse`).

## Schritt 2: Verstehen, bevor du zusammenfasst

Lies die LE einmal komplett durch und identifiziere:

- Das **Kernthema** der LE (worum dreht sich alles).
- Die **3–7 wichtigsten Konzepte/Aussagen** — das, was hängenbleiben muss.
- Alle **Fachbegriffe**, die ein Einsteiger nicht kennt (die musst du in Schritt 3 auflösen).
- Falls erkennbar (aus Titel, Nummer, Vault-Kontext): zu **welchem Modul** die LE gehört und wo sie im Stoffverlauf steht (Grundlage? Vertiefung? Anwendung?).

## Schritt 3: Zusammenfassung ausgeben

Gib die Zusammenfassung in **genau dieser Struktur** aus. Durchgehend leicht verständlich: kurze Sätze, jeder Fachbegriff wird beim ersten Auftreten in Klammern oder einem Nebensatz erklärt, wo es hilft mit einer Alltags-Analogie.

```markdown
## 📌 Worum geht es in dieser LE?
2–4 Sätze, die einem kompletten Einsteiger sagen, was das Thema ist und
warum es relevant ist. Kein Fachjargon ohne Erklärung.

## 🧠 Kerninhalte — leicht erklärt
Jedes Kernkonzept als **eigener, abgesetzter Block** — NICHT als flacher
Stichpunkt in einer langen Liste (das wird unübersichtlich, gerade dieser
Teil ist der wichtigste). Pro Konzept dieses Muster:

#### <Nr-Emoji> Begriff (Fachterm in Klausursprache, falls fremdsprachiges Modul)

(⚠️ Immer ein **Leerzeichen** zwischen Zahl-Emoji und Begriff — `1️⃣ Begriff`, nicht `1️⃣Begriff` — sonst klebt das Emoji am Text.)
> **Kernaussage in EINEM Satz** — ggf. die Formel/Kennzahl fett.

2–3 kurze Erklärsätze in einfachen Worten, als hörte man den Begriff zum
ersten Mal; Analogie wo sie hilft.
**Merke:** die eine Zahl/Faustregel, die hängenbleiben muss · **Beispiel:** …

Zwischen den Blöcken eine Leerzeile. Faustregeln zur Darstellung:
- Kernaussage immer als `> Blockquote` oben — das ist der Anker beim Scannen.
- Aufzählungen (z.B. mehrere Implikationen) als eingerückte Bullets INNERHALB des Blocks, nicht als Fließtext.
- Passt der Inhalt in ein Raster (Problem→Ursache→Lösung, Begriff→Definition), eine **Markdown-Tabelle** statt Prosa.
- Lieber wenige, klar getrennte Blöcke (3–7) als eine dichte Bullet-Wand.

## 🧩 Einordnung ins Modul
Wo steht diese LE im Modul? Baut sie auf etwas auf, worauf führt sie hin,
warum kommt sie an dieser Stelle? 2–4 Sätze. Wenn das Modul unbekannt ist,
das offen sagen statt zu raten.
```

Regeln für die Ausgabe:
- **Zusammenfassung IMMER auf Deutsch** — egal in welcher Sprache das Content-PDF/Modul ist. Erklärungen, Überschriften, Merksätze: durchgehend deutsch, weil das die Verständnissprache ist.
- **Fremdsprachige Klausur → Fachbegriffe in Klammern in der Klausursprache mitführen.** Ist das Modul/die LE nicht deutsch geprüft (Detektor: Frontmatter `klausur-sprache` ≠ DE, fremdsprachiges Content-PDF, oder erkennbar fremdsprachiger Stoff), dann bei **jedem** Fachbegriff den Originalterm in Klammern mitgeben — die deutsche Erklärung bleibt, aber Tim muss den Term in der Klausur abrufen können (z.B. „reibungsfreie Gravity (**frictionless gravity**)", „Grenzeffekt (**border effect**)"). Im Zweifel (Sprache unklar) den Originalterm lieber mitführen als weglassen. Bei deutsch geprüftem Modul entfällt die Klammer.
- **Kein vorausgesetztes Vorwissen** — die Zielperson kennt das Thema nicht. Wenn du einen Begriff nutzt, den die LE selbst als bekannt annimmt, erkläre ihn trotzdem.
- **Treu zur Quelle** — nichts dazu erfinden, was nicht in der LE steht. Fehlt Information für die Modul-Einordnung, das transparent machen statt zu halluzinieren.
- **Kompakt** — im Zweifel lieber ein klares Bild als vollständige Detailtiefe; das ist eine Zusammenfassung, kein Skript-Ersatz.

Abschließend `skill-optimize` mit `le-zusammenfassen` aufrufen.

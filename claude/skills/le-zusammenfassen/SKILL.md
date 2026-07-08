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
Die wichtigsten Konzepte, je eines als kurzer Absatz oder Bullet mit
**fettem Stichwort** vorne. Jeden Begriff so erklären, als hörte man ihn
zum ersten Mal. Analogien einsetzen, wo sie das Verständnis erleichtern.
- **Begriff A** — was es ist, in einfachen Worten.
- **Begriff B** — ...

## 🧩 Einordnung ins Modul
Wo steht diese LE im Modul? Baut sie auf etwas auf, worauf führt sie hin,
warum kommt sie an dieser Stelle? 2–4 Sätze. Wenn das Modul unbekannt ist,
das offen sagen statt zu raten.
```

Regeln für die Ausgabe:
- **Kein vorausgesetztes Vorwissen** — die Zielperson kennt das Thema nicht. Wenn du einen Begriff nutzt, den die LE selbst als bekannt annimmt, erkläre ihn trotzdem.
- **Treu zur Quelle** — nichts dazu erfinden, was nicht in der LE steht. Fehlt Information für die Modul-Einordnung, das transparent machen statt zu halluzinieren.
- **Kompakt** — im Zweifel lieber ein klares Bild als vollständige Detailtiefe; das ist eine Zusammenfassung, kein Skript-Ersatz.

Abschließend `skill-optimize` mit `le-zusammenfassen` aufrufen.

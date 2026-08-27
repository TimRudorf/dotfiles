---
paths:
  - "**/*.js"
  - "**/*.mjs"
  - "**/*.cjs"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/*.pas"
  - "**/*.dpr"
  - "**/*.dpk"
  - "**/*.inc"
  - "**/*.go"
  - "**/*.py"
  - "**/*.sh"
  - "**/*.zsh"
  - "**/*.sql"
  - "**/*.scss"
  - "**/*.css"
---

# Kommentare im Code

Ziel ist nicht *viel* Kommentar, sondern **der richtige an der richtigen
Stelle**. Zwei Sorten, klar getrennt:

## 1. Doc-Kommentare — an der Schnittstelle, im Sprachstandard

Jede **öffentliche** Funktion, Klasse, Methode, Typ und jedes Modul bekommt
einen Doc-Kommentar in der Konvention der Sprache. Private Helfer nur, wenn
ihr Zweck nicht aus Name und Signatur folgt.

| Sprache | Konvention |
|---|---|
| JavaScript | JSDoc — `/** … */` mit `@param`, `@returns`, `@throws` |
| TypeScript | JSDoc/TSDoc, aber **ohne Typen** (`@param name` statt `@param {string} name`) — den Typ hält die Signatur |
| Delphi | XMLDoc — `///` mit `<summary>`, `<param>`, `<returns>` (Help Insight) |
| Go | godoc — Satz beginnt mit dem Bezeichner: `// ParseFoo liefert …` |
| Python | Docstrings nach PEP 257 |
| Shell | Kopfzeile mit Zweck und Aufruf-Beispiel |
| SCSS/CSS | Abschnitts-Header nur für nicht offensichtliche Blöcke |

Sagt ein Doc-Kommentar nichts, was der Name nicht schon sagt (`/** Setzt den
Namen. */` über `setName`), ist er **Lärm** — dann ist der bessere Name der
Fix, nicht der Kommentar.

## 2. Inline-Kommentare — die Ausnahme, nicht die Regel

Der **Default ist kein Kommentar**. Klare Namen und kleine Funktionen tragen
sich selbst. Geschrieben wird nur, was aus dem Code nicht ablesbar ist und
ohne das jemand stolpert: die Absicht hinter einer nicht offensichtlichen
Entscheidung, ein Fallstrick, der Grund für einen Workaround, ein Verweis auf
Spec oder Ticket. **Nicht** die Mechanik — die steht schon da.

**KISS gilt auch für den Kommentar selbst:** ein Satz, im Regelfall eine
Zeile, höchstens zwei. Wer mehr braucht, um eine Stelle zu erklären, hat meist
ein Code-Problem und kein Kommentar-Problem — dann die Stelle vereinfachen
oder besser benennen, statt sie zu beschreiben.

Und nie die **Herleitung**: kein Lösungsweg, keine verworfenen Ansätze, kein
Protokoll dessen, was gerade probiert wurde. Das Ergebnis steht im Code, der
Weg dorthin in Git.

```js
// Schlecht: erzählt, was der Code sagt
i++; // i um eins erhöhen

// Schlecht: erzählt den Lösungsweg statt der Sache
// Zuerst mit setTimeout versucht, hat aber beim Reload gefeuert. Dann
// über den Ready-Event probiert, der kam zu früh. Am Ende Polling, weil
// das Widget kein Signal anbietet.
pollUntilReady();

// Gut: ein Satz, erklärt warum es so aussieht
// Der Server liefert Sekunden, das Widget erwartet Millisekunden.
timeout = response.timeout * 1000;
```

## Was nie in den Code gehört

- **Zwischenstands- und Prozess-Kommentare** — `// neu 2026-08`, `// hier war
  früher X`, `// geändert wegen Ticket 42`, Changelog-Blöcke. Das ist Git.
- **Auskommentierter Code.** Weg damit; die alte Fassung steht in der Historie.
- **`TODO`/`FIXME` ohne Adressat** — entweder mit Issue-Referenz oder gar nicht.
- **Banner und Trenner-ASCII**, die nur Zeilen füllen.
- **Bezug auf den Entstehungsvorgang** — kein „wie besprochen", kein Hinweis
  auf Prompt, Session oder Assistenz.

## Kommentare veralten — das ist ein Defekt

Ein Kommentar, der nach der Änderung nicht mehr stimmt, ist schlimmer als
keiner: er ist eine Falschaussage mit Vertrauensvorschuss. Wer eine Funktion
anfasst, zieht ihren Doc-Kommentar mit — und prüft, ob dieselbe Aussage noch
anderswo steht (README, Interface-Deklaration, aufrufende Stelle).

Dabei wird der bestehende Kommentar **bearbeitet, nicht ergänzt**. Ein zweiter
Satz neben den alten gestellt, eine neue Zeile unter den überholten Hinweis:
so wächst der Kommentar, während seine Aussage unschärfer wird — und am Ende
steht dort beides, richtig und falsch nebeneinander. Die alte Fassung hält
Git.

## Altlasten werden korrigiert, nicht abgestempelt

Ein Kommentar, der gegen diese Regel verstößt, ist ein Defekt — unabhängig
davon, wer ihn wann geschrieben hat. Fällt er bei der Arbeit auf, wird er
**behoben**. »War schon vorher da« ist kein Freispruch, sondern nur eine
Herkunftsangabe.

Zwei Handgriffe:

- **Lärm ersatzlos raus** — auskommentierter Code, Changelog- und
  Zwischenstands-Zeilen, Was-statt-Warum, nacherzählte Lösungswege. Die
  Historie behält alles, was daran wert war behalten zu werden.
- **Fehlendes ergänzen** — hat eine angefasste öffentliche Funktion keinen
  Doc-Kommentar, kommt er jetzt dazu.

**Ausnahme, und die ist wichtig:** Behauptet ein alter Kommentar etwas
Nichttriviales, das im Code nicht mehr sichtbar ist (»darf nicht vor der
Initialisierung laufen«, »Reihenfolge ist hier bewusst so«), kann er der letzte
Träger eines echten Grundes sein. Solche Kommentare nicht auf Verdacht
löschen — Grund klären und den Kommentar in korrekter Form erhalten, oder die
Stelle melden. Das ist derselbe Vorbehalt wie bei verlustbehafteten
Encoding-Fällen: nicht raten.

Umfang: was beim Arbeiten ohnehin gelesen wird. Wird daraus mehr als ein paar
Zeilen, gehört das Aufräumen in einen **eigenen Commit** — sonst versinkt die
eigentliche Änderung im Diff und das Review wird wertlos.

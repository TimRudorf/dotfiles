---
paths:
  - "**/*.pas"
  - "**/*.dpr"
  - "**/*.dpk"
  - "**/*.inc"
  - "**/*.dfm"
  - "**/*.js"
  - "**/*.mjs"
  - "**/*.cjs"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/*.go"
  - "**/*.py"
  - "**/*.sh"
  - "**/*.zsh"
  - "**/*.sql"
  - "**/*.html"
  - "**/*.scss"
  - "**/*.css"
---

# Sprache im Code

Drei Schichten, drei Sprachen. Die Trennlinie ist immer dieselbe Frage:
**wer liest das?**

| Schicht | Sprache | Beispiele |
|---|---|---|
| **Bezeichner** — die Maschine und jeder Entwickler | **Englisch** | Klassen, Methoden, Variablen, Konstanten, Parameter, CSS-Klassen, Test-Namen |
| **Kommentare** — das Team | **Deutsch** | Doc- und Inline-Kommentare |
| **Anwender-sichtbare Texte** — der Kunde | **Deutsch** | Labels, Buttons, Captions, Meldungen, Tooltips, Validierungstexte, Ausgaben in Mail/PDF/Druck |

## Warum diese Aufteilung

Bezeichner sind das Fachvokabular des Programmierens; Sprachen, Frameworks und
Bibliotheken sind englisch, und ein deutscher Name mitten in englischer
Umgebung erzeugt Brüche (`ladeBenutzerListe` neben `Array.prototype.filter`).

Kommentare erklären **Absicht**, und Absicht wird hier auf Deutsch gedacht und
besprochen. In einer Fremdsprache formuliert verliert sie genau die Nuance,
derentwegen der Kommentar überhaupt steht.

Die Anwender sind deutschsprachig. Ein englischer Text im UI ist kein Stilfehler,
sondern ein Produktfehler.

## Woran ein Verstoß erkennbar ist

```js
// Falsch: deutscher Bezeichner, englischer Anwendertext
function ladeEinsaetze() { … }
button.textContent = 'Save';

// Richtig: englisches Gerüst, deutscher Kommentar, deutscher Anwendertext
/** Lädt die offenen Einsätze des angemeldeten Benutzers. */
function loadOpenEinsaetze() { … }
button.textContent = 'Speichern';
```

Die Tags der Doc-Konvention sind Syntax und bleiben englisch (`@param`,
`@returns`, `<summary>`) — der Fließtext dahinter ist deutsch.

Bei Meldungstexten gilt der Zweifel zugunsten von Deutsch: eine englische
Meldung vor dem Anwender ist ein Defekt, ein deutscher Log-Eintrag nur unschön.
Rein technische Diagnose (Log, interne Exception, Debug-Ausgabe) bleibt englisch.

## Wo die Grenze liegt

- **Fachbegriffe der Domäne bleiben deutsch**, wo die Übersetzung den Bezug
  kappt: Einsatz, Abschnitt, Wache, Melder, Stichwort, AAO. Ein
  `IncidentSection` neben einer `ABSCHNITT`-Tabelle kostet mehr, als es bringt.
  Englisches Gerüst plus deutscher Fachbegriff ist richtig (`getAbschnittById`),
  die Umkehrung nicht (`holeSectionById`).
- **Datenbank-Bezeichner bleiben, wie sie sind.** Das EDP-Schema ist deutsch
  (`ABSCHNITT`, `ALARMIERT`, `ANFAHRT`); Felder und Records, die eine Spalte
  spiegeln, dürfen deren Namen tragen. Diese Regel benennt nichts in der DB um.
- **Bestand wird nicht auf Verdacht umbenannt.** Angepasst wird, was ohnehin
  angefasst wird — und auch das nur ohne externe Bindung. Ein Bezeichner, der in
  einem WS-Telegramm, einer REST-Antwort, einer Action-Route oder einem
  DFM-Verweis steckt, bleibt.
- **Generierte Bezeichner** wie Delphi-Event-Handler aus Captions
  (`Abschnittauflösen1Click`) werden nicht von Hand verbogen.
- Trägt ein deutscher Fachbegriff einen Umlaut, wird er im Bezeichner zu ASCII
  (`Einsaetze`) — im Kommentar und im Anwendertext daneben steht er trotzdem
  richtig.
- Doku, README, Commit-Botschaft, PR-Body und Issue sind **nicht** Gegenstand
  dieser Regel.

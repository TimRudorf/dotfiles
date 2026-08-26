---
name: edp-frontend-design
description: >-
  Verbindliche Design-Sprache für alle EDP-Web-Oberflächen (edpweb, edp:command, Abschnittsverwaltung).
  Setzt auf den generischen `frontend-design:frontend-design`-Skill auf, ersetzt dessen freie
  Stilwahl aber durch Microsofts Fluent 2 als Vorbild und den EDP-Kanon. Nutzen bei JEDER Arbeit an
  UI, Layout, SCSS, Templates, Modalen, Ribbon, Panels, Farben, Typografie oder Icons in einem
  EDP-Web-Projekt — auch wenn die Aufgabe nur „einen Dialog anpassen" lautet. Trigger: "design",
  "UI", "Oberfläche", "sieht nach KI aus", "auf Fluent 2 anpassen", "Optik", "Styling", "SCSS",
  "Modal", "Ribbon", "Anzeigeoptionen", "/edp-frontend-design".
argument-hint: "[ui-bereich oder designziel]"
---

# EDP Frontend-Design

Die Design-Sprache für EDP-Web-Oberflächen. **Vorbild ist Fluent 2**, nicht der eigene Geschmack und
nicht der jeweils modische Default.

> **Dieser Skill hält den Kanon, nicht die Fakten.** Die belegten Fluent-2-Werte (Tokens,
> Komponenten-Anatomie, Bootstrap-Reibungspunkte) stehen in `$VAULT/referenz/fluent2-design.md` und
> werden hier **nur verlinkt**, nie kopiert. Beim Umsetzen die Referenz lesen und ihr folgen — nicht
> aus dem Gedächtnis raten. `$VAULT` = host-abhängiger Vault-Root (siehe CLAUDE.md).

## Voraussetzungen

- Projekt: ein EDP-Web-Projekt unter `$EDP_PROJECT_ROOT` (meist `edpweb`)
- Datei: `$VAULT/referenz/fluent2-design.md` — die Faktenbasis
- Datei: `$VAULT/tim/feedback/edpweb-ui-design-prinzipien.md` — Tims Bestandsregeln

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Schritt 1: Basis-Skill laden

Zuerst `frontend-design:frontend-design` aufrufen. Er liefert das **Handwerk**: in zwei Durchgängen
arbeiten (planen → gegen den Brief prüfen → bauen → selbst kritisieren), Typografie als Träger der
Persönlichkeit, Struktur muss etwas Wahres kodieren statt zu dekorieren, Mut an genau einer Stelle
ausgeben, am Ende ein Accessoire wieder abnehmen.

**Was aus dem Basis-Skill NICHT gilt:** seine freie Stilwahl. Er fordert eine eigenständige, nicht
verwechselbare Handschrift — hier ist die Handschrift bereits gesetzt: **Fluent 2 plus EDP-Kanon.**
Der Brief gewinnt, und dieser Skill *ist* der Brief. Die Kreativität geht in Struktur, Informations-
dichte und Bedienlogik, nicht in Palette und Formensprache.

## Schritt 2: Fakten holen statt raten

`$VAULT/referenz/fluent2-design.md` lesen — mindestens die Abschnitte, die den aktuellen Bereich
betreffen. Dort stehen echte Werte aus `@fluentui/tokens`, keine Prosa.

> ⚠️ **`fluent2.microsoft.design` veröffentlicht keine einzige CSS-Zahl.** Wer Zahlen von dort
> zitiert, hat sie erfunden. Site = Haltung und Usage, Code (`@fluentui/tokens`) = Werte.
> Bei Widerspruch gewinnt für Web der Code.

## Schritt 3: Der EDP-Kanon

Diese Regeln gelten zusätzlich zu Fluent 2 und **gehen im Konfliktfall vor**.

### 3a — Farbe

- **Primary ist abgeschafft.** `--bs-primary` / `btn-primary` / `link-primary` / `text-primary` /
  `bg-primary` und alle `--bs-primary-rgb`-Ableitungen werden in EDP-Oberflächen **nicht mehr
  verwendet**. Der Interaktionsakzent ist **Secondary**. Neuer Code darf Primary nicht einführen;
  berührter Bestandscode wird mitgezogen.
- **Rot bleibt Semantik.** Löschen, Entziehen, Abschließen, Fehler, Alarm — dafür ist `danger` da,
  und nur dafür. Fluent sagt es hart: „Don't use semantic colors for decoration."
- **Akzent als Variable, nicht als Literal.** Pro Komponentenfamilie eine CSS-Variable
  (`--edp-elw-accent`, `--edp-ribbon-accent`, `--edp-panel-accent`), damit ein Modul lokal
  abweichen kann, ohne Regeln zu duplizieren.
- **Dark-Mode ist keine Invertierung.** Secondary geht auf dunklem Grund unter — dort aufhellen
  (`color-mix(in srgb, var(--bs-secondary) 45%, var(--bs-body-color))`). Fluent macht es genauso:
  Vordergrund/Stroke werden heller, Flächen dunkler.
- **Einsatzstatus darf lauter sein als Fluent.** Flächige Farbcodierung für Alarm/Priorität/Status
  ist erlaubt und nötig — aber aus der *semantischen* Palette, nie aus dem Interaktionsakzent, und
  **immer mit zweitem Träger** (Icon + Text). Farbe nie als einziger Informationsträger.

### 3b — Typografie

- **Keine Versalien, keine Sperrung.** Fluent 2 hat dafür nicht einmal ein Token.
  `text-transform: uppercase` und `letter-spacing` sind in EDP-Oberflächen Fehler, kein Stilmittel.
  Ausnahme: fachlich vorgegebene Kürzel (Funktionskürzel, Statuscodes).
- **Kein Monospace für Überschriften.** Monospace nur für echte Maschinendaten (Koordinaten,
  Rufnamen-Raster, Logausgaben).
- **Betonung über Gewicht 600, nicht über Größe oder Farbe.**
- **Zweistufige Textfarbe** trägt die Hierarchie: Fließtext dunkel, Sekundärtext eine Stufe heller.

### 3c — Fläche, Linie, Tiefe

- **Gruppieren über Weißraum und Grauabstufung, nicht über Linien.** Zierlinien neben Überschriften,
  dekorative Trenner und Punkte vor Labels sind ersatzlos zu entfernen — **inklusive ihres Markups**,
  sonst bleiben leere Elemente stehen.
- **Schatten oder Rahmen, nie beides.**
- **Schatten nur für echte z-Ebenen** (Popover, Panel, Dialog). In der Fläche ausschließlich
  Hintergrundabstufung — bei hoher Datendichte erzeugen Schatten nur Rauschen.
- **Kein Card-in-Card.** Modal und Draggable bekommen keinen zusätzlichen Card-Wrapper.
- **Enge Radien.** Kein durchgehendes 12–16 px. Klein bleibt klein.

### 3d — Interaktion

- **Gedrückt heißt dunkler, nicht tiefer.** Kein Inset-Schatten, kein Versatz, keine Skalierung —
  nur eine Rampenstufe dunklere Füllung. Das ist der Fluent-Griff, den man beim Klicken spürt.
- **Fokus ist ein deckender Ring, kein Glow** — und er erscheint nur bei Tastaturbedienung
  (`:focus-visible`). Bootstraps halbtransparenter Fokus-Halo ist der lauteste un-fluentige Marker
  und gehört global ersetzt.
- **Leise Buttons für Werkzeugleisten.** Randlos im Ruhezustand, Fläche erst bei Hover. Nur **ein**
  betonter Button pro Ansicht.
- **Keine Auto-Refresh-Intervalle.** Aktualisierung über Websocket-Ereignisse.

### 3e — Dichte und Touch

EDP ist Einsatzleitsoftware: viel Information, Bedienung unter Stress, oft auf Tablets.

- **Fluents Vokabular übernehmen, die untere Hälfte seiner Rampen wählen.** „Roomy visual rhythm"
  ist für eine Leitstelle bewusst zurückzunehmen.
- **Alles Antippbare bleibt groß**, auch wenn die Anzeige dicht ist — notfalls Trefferfläche per
  Padding oder Pseudo-Element über die sichtbare Fläche hinaus vergrößern.
- **Sekundäraktionen nie nur auf Hover.** Unter Zeitdruck und auf Touch ist das unbedienbar.
- **Kein Text-Abschneiden bei Meldungen.** Einsatzrelevante Inhalte werden umgebrochen, nicht gekürzt.

### 3f — Bestandsintegration

- **Suche über `EDPHeaderSearch.registerProvider`**, nicht als Ribbon-Slot.
- **Ribbon im ELW-Stil**: einzelne Buttons mit `.active`-Mapping, `showConfigurator: false`,
  einzelne Sub-Filter-Buttons mit `relevantViews` statt Radio-Gruppen.
- **Anzeigeoptionen-Panel** mit Sections per `data-relevant-views`.
- **ELW-Modul ist die Referenzimplementierung** — im Zweifel dort nachsehen, wie es gelöst ist.

Volltext und Begründungen: `$VAULT/tim/feedback/edpweb-ui-design-prinzipien.md`.

## Schritt 4: Umsetzen

- **Erst Grundraster, dann Details.** Radius, Höhen, Textgrößen und Fokus wirken auf jeden Pixel
  gleichzeitig; Detailkorrekturen darüber wirken sonst aufgesetzt. Die Reihenfolge der fünf
  wirksamsten Eingriffe steht in der Referenz.
- **Über CSS-Variablen steuern, nicht über Einzelregeln.** Bootstrap 5 hat pro Komponente
  Variablen — die zu belegen ist billiger und konsistenter als Selektoren zu überschreiben.
- **Geteilte Klassen bewusst behandeln.** Vor jeder Änderung prüfen, welche Module eine Klasse
  mitbenutzen. Nur was ausschließlich außerhalb der EDP-Web-Oberflächen liegt, bleibt außen vor.
- **Toten Code mitnehmen.** Regeln, deren Selektor nirgends greift, ersatzlos entfernen statt
  umzufärben — und im Bericht benennen.
- **Encoding**: Frontend-Dateien sind UTF-8, echte Umlaute. Delphi-Dateien bleiben Windows-1252.

## Schritt 5: Selbst prüfen, bevor Tim prüft

Nie „sieht gut aus" behaupten, ohne es gemessen zu haben. Verifikation läuft **auf der Dev-VM**
(`/edp-design-loop`), nicht lokal.

Messbare Abnahmekriterien statt Bauchgefühl — per `playwright-cli eval` auslesen:

```
Treffer für bs-primary im berührten SCSS         → muss 0 sein
getComputedStyle(...).textTransform               → 'none'
getComputedStyle(...).letterSpacing               → 'normal'
Anzahl dekorativer Trenner / Indikator-Punkte     → 0
--edp-*-accent                                    → aufgelöster Secondary-Wert
Fokus bei Mausklick                               → kein Ring
Fokus bei Tastatur                                → deckender Ring
```

Screenshots in **hell und dunkel**. Bei Layoutfragen zusätzlich die Render-Kette per `eval` prüfen,
statt zu raten (`overflow`, `position`, `z-index` der Vorfahren).

## Schritt 6: Den Kanon mitwachsen lassen

Dieser Skill ist **absichtlich unfertig**. Jedes Mal, wenn Tim eine Designentscheidung trifft oder
korrigiert, gehört sie hier hinein — sonst wird dieselbe Diskussion in drei Wochen erneut geführt.

- **Regel mit Begründung** → Abschnitt 3, in die passende Untersektion, als knappe Anweisung.
- **Belegter Fluent-Fakt** → `$VAULT/referenz/fluent2-design.md`, nicht hierher.
- **Wiederkehrendes Umsetzungsmuster** → eigener Abschnitt oder `reference.md` im Skill-Verzeichnis.

Nach jeder Erweiterung den Dotfiles-Roundtrip fahren, damit die Regel auf allen Hosts gilt.

## Regeln

- **Fluent 2 ist das Vorbild, nicht die Bibliothek.** Wir bauen die Anmutung in Bootstrap 5 nach und
  ziehen keine Fluent-Pakete ein.
- **Kein Wert ohne Beleg.** Zahlen kommen aus der Referenz oder aus dem Code — nicht aus dem Gefühl.
- **Kein Hinweis auf AI** in Code, Kommentaren, Commits oder PRs. Deutsch mit echten Umlauten.
- **Im Zweifel weniger.** Fluents 80/20-Formel: erwartbares Grundraster, Gestaltungsenergie nur an
  wenigen Signaturstellen.

Abschließend `skill-optimize` mit `edp-frontend-design` aufrufen.

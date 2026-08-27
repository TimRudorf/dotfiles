---
paths:
  - "**/*.md"
---

# Texte und Beschreibungen

Gilt für alles Geschriebene, das kein Code ist: README, Doku, Issue, PR-Body,
Commit-Botschaft, Vault-Notiz, Bericht.

## Das Wesentliche zuerst

Der erste Absatz beantwortet die Frage, mit der jemand herkommt — nicht die
Vorgeschichte, nicht der Aufbau des Dokuments. Wer nach drei Zeilen aufhört zu
lesen, soll das Wichtigste haben.

Kriterium: **in zwei Minuten überfliegbar und danach handlungsfähig.**

## Kurz heißt: Prosa raus, Substanz bleibt

Gekürzt wird das Drumherum — Einleitungen, Wiederholungen, Ankündigungen
dessen, was gleich kommt, Höflichkeitsformeln. Nie die Substanz: ein
Prüfschritt ohne sein Kriterium und eine Warnung ohne ihren Grund sind wertlos
gekürzt, nicht knapp.

Struktur trägt mehr als Formulierung:

- Tabelle, wo es Spalten gibt.
- Aufzählung, wo es Punkte sind.
- Zwischenüberschrift, sobald mehr als ein Gedanke im Text steht.

## Bearbeiten, nicht anhängen

Muss ein Text geändert werden, wird **die betroffene Stelle geändert** — kein
Nachtrag ans Ende. Anhängen ist der bequemere Weg und hat drei Folgen:

- Der Text quillt auf, während der Inhalt gleich bleibt.
- Es entstehen Widersprüche, weil die alte Aussage stehen bleibt.
- Der Leser muss selbst herausfinden, welche Fassung gilt.

Woran ein Nachtrag erkennbar ist: „Update:", „Ergänzung:", „Hinweis: siehe
oben", ein zweiter Abschnitt zum selben Thema, ein Datum im Fließtext. Findet
sich so etwas beim Bearbeiten, wird es **eingearbeitet statt fortgesetzt** —
auch wenn es nicht von der aktuellen Änderung stammt.

Was dabei wegfällt, ist nicht verloren: Git, Issue-Verlauf und
Ticket-Kommentare halten den Werdegang. Der Text selbst zeigt den **gültigen
Stand**.

## Echte Umlaute

ä ö ü ß, nicht ae/oe/ue/ss — ohne Ausnahme, und gerade dort, wo der Reflex
ASCII sagt:

- Commit-Botschaften und PR-Titel
- Issue-Titel und Branch-Beschreibungen
- Strings und Kommentare im Code

Ausgenommen ist nur, wo das Zielsystem sie technisch nicht trägt: Dateinamen,
URL-Slugs, Bezeichner im Code. Das ist eine Umgehung aus Notwendigkeit, kein
Stilmittel — im Fließtext daneben stehen sie trotzdem.

## Wo die Grenze liegt

Kurz ist kein Selbstzweck. Ein Thema, das fünf Absätze braucht, bekommt fünf —
es bekommt nur keinen sechsten aus Gewohnheit. Und kein Text wird so weit
eingedampft, dass der Leser rückfragen muss: eine Rückfrage kostet mehr als
die drei Zeilen, die sie erspart hätte.

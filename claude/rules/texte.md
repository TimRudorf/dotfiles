# Texte und Beschreibungen

Gilt für alles Geschriebene, das kein Code ist: README, Doku, Issue, PR-Body,
Commit-Botschaft, Vault-Notiz, Bericht.

> Diese Regel trägt bewusst **kein** `paths:`. Ihr Hauptanwendungsfall — ein
> PR-Body, ein Issue-Text, eine Commit-Botschaft, ein Bericht — ist gar keine
> Datei im Baum. An `**/*.md` gebunden hätte sie genau dort nie geladen.

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

Das gilt auch **unter** dem Text: eine Korrektur, ein Nachtrag oder eine
Richtigstellung als Kommentar zu posten, ist dasselbe Anhängen — nur eine
Ebene tiefer. Wer den Vorgang öffnet, liest den Text und hält ihn für gültig;
dass drei Bildschirme weiter unten steht, dass eine Zahl darin nicht mehr
stimmt, findet er nicht. Also: **den Text ändern.** Der Kommentarstrang ist
für das Gespräch mit anderen da, nicht für Notizen an sich selbst.

## Was in einen Vorgang gehört — und was nicht

Ein PR- oder Issue-Text wird von einem Menschen gelesen, der **entscheiden**
muss. Er beantwortet vier Fragen, in dieser Reihenfolge:

1. **Was ändert sich** — das Ergebnis, nicht der Weg dorthin.
2. **Warum** — ein Satz. Die Vorgeschichte steht im Issue, nicht hier.
3. **Wo soll ich hinschauen** — die heiklen Stellen, benannt und begründet.
4. **Was muss ich prüfen** — was schon läuft, und was offen ist.

Nicht hinein gehören: der Werdegang („erst hatte ich X, dann Y"), verworfene
Ansätze, Messprotokolle, Rebase- und Formatier-Hinweise, und Begründungen für
Dinge, die *nicht* getan wurden — es sei denn, eine davon ist eine
Entscheidung, der der Leser widersprechen können soll. Das alles steht in Git,
im Issue und im Ticket.

Faustzahl: **ein Bildschirm.** Wer scrollen muss, um zu sehen, was er prüfen
soll, prüft es nicht.

Belege, die trotzdem hingehören — Messtabellen, Fundstellenlisten —, kommen in
einen `<details>`-Block. Sie bleiben nachlesbar, ohne den Text zu füllen.

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

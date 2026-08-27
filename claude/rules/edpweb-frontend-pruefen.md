---
paths:
  - "**/edpweb/**/*.js"
  - "**/edpweb/**/*.mjs"
  - "**/edpweb/**/*.html"
  - "**/edpweb/**/*.scss"
  - "**/edpweb/**/*.css"
---

# Frontend-Änderungen im Browser prüfen

Eine Frontend-Änderung an einem EDP-Web-Projekt wird **auf der Dev-VM gegen das echte
edp:web-Backend** geprüft, nie gegen eine lokal gerenderte Seite. Der Weg ist:
Stand auf die VM bringen (`edp-ctrl dev compile <projekt>`, bei reinen Frontend-Edits
zusätzlich `npm ci && npm run build` auf der VM), dann `playwright-cli` gegen
`https://<VM-IP>/` — anmelden, Zielseite aufrufen, `console` und `snapshot` lesen.
Die Schrittfolge samt VM-Lock steht in `edp-design-loop`.

## Warum

Eine lokal gerenderte Vorlage ist kein Prüfling. Ihr fehlen Session, `presql`-Werte,
die Delphi-Platzhalterersetzung und jeder Datenendpunkt. Was dann in der Konsole steht,
ist Rauschen aus fehlenden Abrufen — und das echte Verhalten steckt genau dort, wo
Daten ankommen. Wer so misst, hält eine Seite für heil, die im Betrieb weiss bleibt.

## Woran ein Verstoss erkennbar ist

Ein Probelauf, der einen eigenen Webserver hochzieht, `file://` öffnet, die Vorlage mit
einem Testhilfsmittel rendert oder Netzabrufe stubbt. Genauso: ein Screenshot ohne
vorangegangene Anmeldung — die Seite zeigt dann den Anmeldebildschirm, nicht den
Prüfling.

## Wo die Grenze liegt

Die Regel verlangt keine Browser-Probe für jede Änderung. Sie sagt nur, **wie** geprüft
wird, wenn geprüft wird. jsdom-Tests unter `development/tests/` bleiben der Normalfall
und ersetzen die Browser-Probe überall dort, wo kein Ladezeitpunkt, keine echte
Bibliothek und kein Vorlagen-Ereignisattribut im Spiel ist.

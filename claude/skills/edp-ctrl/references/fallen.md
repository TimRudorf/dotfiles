# edpweb — Fallen & Regeln beim automatisierten Zugriff

Hintergrundwissen für Agents, die über `edp-ctrl` schreibend/lesend auf einen
edpweb-Server zugreifen. Ergänzt die verbindlichen Regeln in `SKILL.md`.

## Instanzen: Test vs. Produktiv/Demo

- Schreibende Aktionen **nur** gegen eine ausdrücklich als Test-/Entwicklungsinstanz
  konfigurierte edpweb-Instanz ausführen.
- **Nie gegen eine Kunden-Demo** (z.B. eine öffentliche `demo.*`-Instanz): dort sehen
  echte Kunden die Daten — jede Testaktion hätte Außenwirkung.
- Welche Instanz aktiv ist, ergibt sich aus der `edp-ctrl`-Konfiguration (Profil).

## Zeichensatz

- edpweb (Pascal/FireDAC) verschluckt **4-Byte-UTF-8** (Emojis werden zu `?`).
- In Freitextfeldern (Meldung, Bemerkung, Eintrag …) **keine Emojis**. Stattdessen
  Marker: `[KI]`, `[BOT]`, `[Jarvis-Test]`.
- 3-Byte-Zeichen (Umlaute ä/ö/ü/ß, typografische Anführungszeichen) sind unkritisch.

## Testdaten

- Testeinsätze mit Präfix **`Jarvis-Test`** kennzeichnen — leicht identifizier- und
  aufräumbar.
- **Reservierte Einsatznummern-Bereiche meiden.** Bestimmte Nummernkreise sind für
  automatisierte Auswertungen (LLM-Evals) reserviert und dürfen nicht mit manuellen
  Tests vermischt werden. Im Zweifel den Bereich vorher erfragen/prüfen.
- Nach dem Test aufräumen (Einsatz schließen bzw. Testdaten entfernen).

## Anmeldung & Session

- **Passwörter nie raten.** Nach wenigen Fehlversuchen (Größenordnung 5 in 5 Minuten)
  wird der Benutzer temporär gesperrt. Nur mit bekannten, gültigen Zugangsdaten anmelden.
- Die Session (Cookie) ist **an die Quell-IP gebunden** und **zeitlich begrenzt**
  (Server-Timeout). `edp-ctrl` erneuert sie bei Bedarf automatisch — aber Requests
  sollten vom selben Host laufen wie die Anmeldung.
- Für Benutzer mit erzwungener 2-Faktor-Authentifizierung sind reine Skript-Logins nicht
  möglich; dafür einen Test-Benutzer ohne 2FA verwenden.

## Read-back-Pflicht

Nach jeder schreibenden Aktion (Einsatz anlegen, Status setzen …) das Ergebnis über eine
Abfrage (`json …`) zurücklesen und gegen die Absicht prüfen, **bevor** die Aktion als
erfolgreich gemeldet wird. Ein leerer HTTP-200-Body heißt bei edpweb nicht automatisch
Erfolg — die Wirkung verifizieren.

## Fehlerdiagnose

Bei HTTP-Fehlern (4xx/5xx) zuerst den **vollständigen Antwort-Body** lesen, nicht nur den
Statuscode: edpweb liefert die eigentliche Fehlerursache oft als Text/HTML im Body (ein
403 kann z.B. „Einsatz bereits geschlossen" bedeuten, nicht ein Rechteproblem).

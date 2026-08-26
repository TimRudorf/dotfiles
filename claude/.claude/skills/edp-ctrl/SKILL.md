---
name: edp-ctrl
description: CLI zum Interagieren mit EDP (edpweb) — Anmelden, Aktionen/Abfragen gegen einen edpweb-Server, (optional) Kompilieren, Logs und Dienste auf einer Dev-VM (SSH) oder lokal, sowie (optional) Direktzugriff auf die EDP-Datenbank für die Schnittstellen-Konfiguration. Use when an agent needs to log into edpweb, trigger actions, query data, reproduce a bug, test a feature, build/run an EDP project, or read and change the interface configuration via the `edp-ctrl` command.
allowed-tools: Bash(edp-ctrl:*)
---

# edp-ctrl

`edp-ctrl` ist ein CLI, mit dem du (als Agent) mit EDP interagierst — vor allem, um
**Bugs zu reproduzieren und Features zu testen**, ohne mit `curl`/SSH von Hand zu
hantieren.

Drei Schienen:

- **HTTP** (edpweb): anmelden, Aktionen auslösen, Daten abfragen. Braucht nur
  HTTPS-Erreichbarkeit eines edpweb-Servers. Generischer Durchgriff auf jeden Endpoint
  über `json` (lesend) und `action` (mutierend), daneben typisierte Wrapper für den
  Alltagspfad.
- **Dev** (optional): kompilieren, Logs streamen, Dienste steuern — remote (SSH zur
  Dev-VM) oder lokal.
- **DB** (optional): Direktzugriff auf die EDP-Datenbank — **nur** für Daten, die kein
  HTTP-Endpoint hergibt (heute: die Schnittstellen-Konfiguration).

## Maßgebliche Quelle: `--help`

Welche Kommandogruppen es _jetzt_ gibt, sagt `edp-ctrl --help`, was eine Gruppe kann
`edp-ctrl <gruppe> --help` — per Definition synchron zur installierten Version.

> ⚠️ Dieser Skill wächst mit dem Tool. Wenn ein hier beschriebenes Kommando von
> `--help` abweicht, **gilt `--help`**. Bei „VERALTET" in `edp-ctrl skills status`:
> `edp-ctrl skills install` (oder `edp-ctrl update`) ausführen.

Typische Aufrufe je Kommandogruppe, Read-back-Wege und kommandospezifische Fallstricke:
[references/kommandos.md](references/kommandos.md).

## Reproduzier-Muster für Bugs und Features

**Anlegen → mutieren → zurücklesen.** Einsatz via `action einsatz/saveeinsatz …
target=einsatznummer` (bzw. `einsatz create`) anlegen — beides gibt die Einsatznummer
aus —, den Zustand mutieren, dann per `json …` zurücklesen und gegen die Absicht
prüfen. Erst dann gilt die Aktion als erfolgreich (Regel 5).

## Verbindliche Regeln (zeitlos — immer beachten)

Diese gelten unabhängig vom Kommando-Umfang. Details in
[references/fallen.md](references/fallen.md).

1. **Nur gegen Test-/Dev-Instanzen arbeiten, NIE gegen die Kunden-Demo.** Schreibende
   Aktionen (Einsatz anlegen, Status setzen) laufen ausschließlich gegen eine dafür
   vorgesehene Instanz (Tims Dev-VM / persönliche Instanz), **niemals** gegen
   `demo.edpweb.de` — dort sehen echte Kunden die Daten.
2. **Keine Emojis / 4-Byte-Zeichen in Freitextfeldern** (Meldung, Bemerkung …). Der
   Server verschluckt sie (`?`). Marker wie `[KI]`, `[BOT]`, `[KI-Test]` verwenden.
3. **Testdaten kennzeichnen** (Präfix `KI-Test`) und **reservierte
   Einsatznummern-Bereiche meiden** (siehe references/fallen.md).
4. **Passwörter nie raten.** Nach wenigen Fehlversuchen sperrt der Server den Benutzer
   temporär. Immer mit bekannten, gültigen Zugangsdaten anmelden.
5. **Nach jeder schreibenden Aktion das Ergebnis zurücklesen** (Read-back), bevor du sie
   als erfolgreich meldest.
6. **Geheimnisse nicht ausgeben.** Weder Passwörter noch Verbindungszeichenketten (DSN)
   gehören in eine Ausgabe, ein Protokoll oder einen Bericht — auch nicht im Fehlerfall.
   Das gilt besonders für die Spalte `SCHNITTSTELLE_DEF.KONFIG`: sie trägt den INI-Text der
   jeweiligen Schnittstelle **im Klartext, inklusive API- und Auth-Keys**.

## Dev-Schiene: erst das Ziel klären

Zwei Ausführungsmodi, gesteuert über den Schlüssel `executor` (`auto`|`local`|`remote`,
Default `auto`):

- **remote** (braucht `vm-host`, SSH zur Dev-VM): commit/push → VM-Sync → Build → EXE holen.
- **local** (nur Windows): baut **in-place im lokalen Arbeitsbaum** gegen die lokal
  installierte Toolchain — kein Git-Push, kein VM-Sync, kein EXE-Rückhol, uncommittete
  Änderungen inklusive. Der Build verändert dabei den Arbeitsbaum und bounct den Dienst
  **deines eigenen Rechners** (Details in references/kommandos.md).

`auto` wählt remote, sobald `vm-host` gesetzt ist, sonst local. Auf Nicht-Windows ist nur
remote möglich.

> ⚠️ **`--executor local` erzwingt lokal — auch wenn `vm-host` gesetzt ist.** Nur `auto`
> richtet sich nach `vm-host`.
>
> **Wenn du auf der VM bauen willst, setz `--executor remote` explizit** statt dich auf
> `auto` zu verlassen — sonst baust du auf einem Windows-Rechner ohne konfigurierten
> `vm-host` still lokal. Und **verifizier das Ziel an der Ausgabe**: die erste Zeile lautet
> `=== Kompiliere <projekt> auf <ziel> ===`, wobei `<ziel>` entweder der `vm-host` oder
> `lokal` ist. Passt das nicht zur Absicht, brich ab und korrigier den Modus.

**Lokal — fehlende Redist-DLLs:** `libcrypto-3-x64.dll`/`libssl-3-x64.dll`/`libmariadb.dll`
liegen bewusst nicht im Git und werden lokal **nicht** bereitgestellt. Auf einem frischen
Checkout fehlen sie; `compile`/`test` geben dann eine `WARNUNG:`-Zeile mit
Download-Kommando aus. **Nimm diese Warnung ernst:** der Build meldet Erfolg, aber die EXE
startet nicht — `dev test` bricht mit **Exit 53 ohne jede Ausgabe** ab. Such den Fehler
dann nicht im Code, sondern hol die DLLs.

## DB-Schiene: nur wo es keinen HTTP-Pfad gibt

`db` greift **direkt** auf die EDP-Datenbank zu. Das ist kein Ersatz für die HTTP-Schiene,
sondern die Ausnahme für Daten, die kein Endpoint hergibt — heute die
Schnittstellen-Konfiguration (`SCHNITTSTELLE_DEF`). **Gibt es für dein Vorhaben einen
`/action/`- oder `/json`-Weg, nimm den**: er läuft durch die echte Validierung des Servers.

```bash
edp-ctrl db ping            # Smoke-Test: nennt Ziel (host:port/dbname) und Serverversion
edp-ctrl db forget          # hinterlegtes DB-Passwort aus dem Keyring entfernen

edp-ctrl schnittstelle list          # alle konfigurierten Schnittstellen, nach ID sortiert
edp-ctrl schnittstelle list --aktiv  # nur, was der edp:server zu dieser Datenbank startet
edp-ctrl schnittstelle list --json   # maschinenlesbar (Rohwerte plus Label)

edp-ctrl schnittstelle enable 2            # STARTTYP = 1  (Autostart)
edp-ctrl schnittstelle enable 2 --manuell  # STARTTYP = -1 (nur manueller Start)
edp-ctrl schnittstelle disable 2           # STARTTYP = 0
edp-ctrl schnittstelle enable LLM          # Auflösung auch über die BESCHREIBUNG
```

`schnittstelle` (Kurzformen `schnittstellen`, `schn`) ist der Einstieg in jede weitere
Schnittstellen-Operation — ohne die Liste ist die ID nicht bekannt.

> 🔴 **`enable` ist eine Aktion mit AUSSENWIRKUNG — behandle sie wie eine.** Eine aktivierte
> Schnittstelle nimmt beim nächsten Serverstart Verbindung zu einem **Fremdsystem** auf
> (Leitstellen-, Alarmierungs- oder Herstellersysteme). Gegen eine Produktivinstallation ist das
> keine reine Konfigurationsänderung. **Prüfe vor jedem `enable`, auf welche Datenbank das Profil
> zeigt** — das Kommando nennt sie in seiner ersten Ausgabezeile, lies sie. Gilt sinngemäß auch für
> `disable`: du schaltest damit eine Anbindung ab, auf die sich jemand verlässt.

Zum Verhalten der beiden Schreibkommandos:

- **Eine rein numerische Angabe ist IMMER eine ID**, nie eine Beschreibung — auch eine Zahl, die
  größer ist als jede vergebbare ID. Unbekannt, mehrdeutig oder leer → Exit-Code ≠ 0 und **kein**
  Schreibzugriff.
- 🔑 **Woran du erkennst, ob geschrieben wurde:** jede Meldung **nach** dem `UPDATE` beginnt mit
  `das UPDATE wurde abgesetzt —`, jede Meldung **davor** endet mit `Es wurde nichts geschrieben.`
  **Richte dich danach, nicht nach dem Wortlaut des Rests.** Nur im zweiten Fall darfst du den
  korrigierten Aufruf gefahrlos wiederholen; im ersten `list` fahren und nachsehen.
- **Der Read-back läuft automatisch.** Erst wenn die zurückgelesene Zeile zur Absicht passt, meldet
  das Kommando Erfolg — du musst ihn nicht selbst nachfahren (Regel 5 ist damit erfüllt).
- ⚠️ **Bei Mehrdeutigkeit nennt die Meldung alle Treffer mit ID** und darunter den fertigen Aufruf
  für **dein** Kommando. Nimm ihn, aber lies das Verb mit: `enable` und `disable` sind hier
  gegenläufige Aktionen, und `enable` ist die mit Außenwirkung.
- **Bereits im Zielzustand ist kein Fehler** („steht bereits auf …", Exit-Code 0, kein Schreibzugriff).
- **Es gibt kein `--all`** und keine Mustertreffer. Willst du mehrere schalten, nenne sie einzeln.
- **Der laufende Prozess wird nicht angefasst.** `disable` beendet keine laufende Schnittstelle,
  `enable` startet keine. Sag das dazu, wenn du eine Änderung meldest.

> 🔴 **„Aktiv" ist zweiteilig.** Der edp:server-Supervisor startet nur, was `STARTTYP > 0`
> **und** `LOWER(STARTPC) = 'localhost'` erfüllt — eine Zeile mit Autostart, aber fremdem
> `STARTPC` lässt er liegen. **Schließe niemals allein aus `STARTTYP` auf „läuft".** In
> `--json` beantwortet das Feld `startet_hier` die Frage fertig; **baue die Prüfung nicht nach** —
> der Wert kommt vom Server aus demselben Ausdruck wie der Filter, und eine Nachbildung in einer
> Programmiersprache driftet von den Vergleichsregeln der Kollation ab (Vollbreiten-Schreibweise,
> Nullbreiten-Leerzeichen).
> `STARTTYP` erscheint als Wort (`Autostart`/`deaktiviert`/`manuell` — auch `-1` ist ein
> dokumentierter Wert), `LOGLEVEL -1` als `Server-Level`, `TYP` bewusst als **Zahl**: das Feld
> ist unzuverlässig gepflegt, baue keine Auswahl darauf.

> ⚠️ Der Supervisor liest die Definitionen **einmal beim Start** des edp:server. Eine Änderung
> wirkt erst nach einem Serverneustart — eine Laufzeit-Steuerung gibt es nicht. Sag das
> dazu, wenn du eine Änderung meldest.

Schlüssel: `db-host`, `db-port` (3306), `db-name` (EDPdb), `db-user`, `db-tls`
(`false`|`true`|`skip-verify`|`preferred`, Default `false`), `db-timeout` (10s, gilt für
Verbindung **und** Abfrage). Passwort **nie** in die Config — `EDPCTRL_DB_PASS` oder
`db ping --password-stdin` (legt es im Keyring ab).

> ⚠️ **Läuft `db ping` nicht, lies die Meldung zu Ende — sie nennt den Schlüssel und das
> Behebungskommando.** Die Meldungen unterscheiden ausdrücklich zwischen Transportproblem
> (`db-host`/`db-port`), Zeitgrenze (`db-timeout`), Anmeldung (`db-user`/Passwort) und
> TLS — such nicht an der falschen Stelle. Häufig: der Server spricht kein TLS, während
> `db-tls` auf `true` steht. Verlangt der Server umgekehrt TLS und führt ein
> selbstsigniertes Zertifikat, ist `db-tls skip-verify` der Weg — mit `true` scheitert
> die Prüfung der Zertifikatskette.

**Einen generischen SQL-Durchgriff gibt es nicht und soll es nicht geben.** Brauchst du eine
lesende Ad-hoc-Abfrage, nimm den `mysql`-Client. Geschrieben wird ausschließlich über
typisierte Kommandos mit Read-back.

## Skill-Verwaltung

```bash
edp-ctrl skills install   # nach ~/.claude/skills/edp-ctrl (--local, --agents: siehe --help)
edp-ctrl skills status    # installierte vs. CLI-Version (Drift-Check)
edp-ctrl update           # Binary aktualisieren + Skill neu installieren
```

Der Skill ist ins `edp-ctrl`-Binary eingebettet und damit immer zur CLI-Version passend.
**Nicht am Installationsort editieren** — Quelle ist das Repo/Binary. `edp-ctrl update`
aktualisiert Binary und Skill gemeinsam (kein Drift). Bei „VERALTET" in `skills status`
genügt `edp-ctrl skills install` bzw. `edp-ctrl update`.

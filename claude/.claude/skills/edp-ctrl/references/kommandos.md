# edp-ctrl — Kommando-Referenz

Ergänzt `SKILL.md`. **Maßgeblich bleibt `--help`** (`edp-ctrl --help`,
`edp-ctrl <gruppe> --help`) — es ist per Definition synchron zur installierten
Version. Diese Datei zeigt die typischen Aufrufe und das, was man den
Hilfetexten allein nicht ansieht: Read-back-Wege, Reihenfolgen und Fallstricke
einzelner Kommandos.

## Erste Schritte

1. **Profil anlegen** und Verbindungsdaten setzen:
   ```bash
   edp-ctrl config init <name>
   edp-ctrl config set base-url <https://…>
   edp-ctrl config set user <benutzer>
   edp-ctrl config set funktion <funktion>
   edp-ctrl config set insecure-tls true   # nur bei selbstsigniertem Zertifikat
   ```
2. **Anmelden** (Passwort via `EDPCTRL_PASS` oder `--password-stdin`):
   ```bash
   EDPCTRL_PASS=… edp-ctrl auth login
   edp-ctrl auth status     # zeigt Anmeldestatus; abgelaufene Sessions werden autom. erneuert
   ```
   Werte lassen sich pro Aufruf per Flag/ENV überschreiben (Präzedenz: Flag → `EDPCTRL_<KEY>` → Profil).

## Aktionen auslösen & Daten abfragen (`action` / `json`)

Generischer Durchgriff auf **alle** edpweb-Endpoints — kein typisierter Wrapper nötig.
Parameter positional (`key=value`) oder per `-P/--param` (mehrfach). Session inkl.
Auto-Relogin kommt aus dem Profil.

```bash
# Lesend — /json/<name> (GET), Antwort ist JSON
edp-ctrl json einsatz/sql/einsatzkurzinfo Einsatznummer=2026999006

# Mutierend — /action/<gruppe>/<name> (POST, form-urlencoded)
edp-ctrl action einsatz/saveeinsatz MELDUNG="[KI-Test] Demo" STICHWORT=H1 target=einsatznummer
edp-ctrl action einsatz/setstatus einsatznummer=<enr> status=Beendet
```

- Endpoints/Parameter/Footguns stehen in der edpweb-Testing-Referenz
  (`actions-einsatz` etc.).
- **Fehler** kommen als lesbare Zeile `Fehler: HTTP <code>: <meldung>` (Exit-Code ≠ 0);
  ein leerer Erfolgs-Body erzeugt keine Ausgabe (Exit-Code 0).

## Typisierte Einsatz-Wrapper (`einsatz`)

Für den Alltags-Pfad rund um Einsätze — benannte Flags statt roher `key=value`-Params.
Für alles andere bleibt `action`/`json` der generische Durchgriff.

```bash
# Anlegen — Einsatznummer geht auf stdout (direkt in eine Variable übernehmbar)
ENR=$(edp-ctrl einsatz create --ort Frankfurt --strasse "Berger Straße" \
        --meldung "[KI-Test] Demo" --stichwort H1 --einsatzart THL)

edp-ctrl einsatz show "$ENR"               # Read-back (Status/Ort/Meldung) — Regel 5
edp-ctrl einsatz setstatus "$ENR" Beendet  # Erfasst|Disponiert|Alarmiert|Beendet|Unwetter
edp-ctrl einsatz close "$ENR"              # endgültig schließen
```

Der Status wird schon **client-seitig** gegen die Whitelist geprüft (kein Fehlversuch
gegen den Server); weitere `saveeinsatz`-Felder gehen bei `create` per `--param key=value`.

Einsatzmittel-Lebenszyklus (Read-back jeweils über `json einsatz/sql/einsatzmittel einsatznummer=<enr>`):

```bash
edp-ctrl einsatz dispo "$ENR" FL-1              # EM auf Einsatz buchen
edp-ctrl einsatz dispo "$ENR" EXT-1 --fremdfahrzeug --typ LF20   # Fremdfahrzeug bei unbekanntem Rufname
edp-ctrl einsatz etb "$ENR" --typ Funk --eintrag "[KI-Test] …" [--von … --an … --sds RN1,RN2]
edp-ctrl einsatz remove-em FL-1 [--grund "…"]   # EM vom Einsatz lösen (vor close nötig)
```

## Einsatzmittel steuern (`em`)

Stammaktionen an Einsatzmitteln (unabhängig vom Buchen auf einen Einsatz). Read-back über
die EM-Liste (`json einsatz/sql/einsatzmittel einsatznummer=<enr>` bzw. `json map/einsatzmittel`).

```bash
edp-ctrl em setstatus FL-1 3                     # FMS-Status 0..9 (client-seitig geprüft)
edp-ctrl em edit FL-1 --besatzung-ges 6 --auftrag "…" --abschnitt -1   # nur gesetzte Felder
edp-ctrl em setpos FL-1 --koordx 8.6821 --koordy 50.1109               # beide zusammen setzen
edp-ctrl em setpos FL-1                          # ⚠️ ohne Koordinaten LÖSCHT der Server die Position
```

## Lageführung / ELW (`lage`, `nachricht`)

`lage select` setzt die aktive Lage in der **Session** — Voraussetzung für `nachricht send`
und andere edpcommand-Aktionen. Read-back über `json edpcommand/lagenarchiv von=… bis=…`
(alle Lagen inkl. AKTIV-Flag) bzw. für Nachrichten `json edpcommand/sql/suche q=…`.

```bash
LID=$(edp-ctrl lage create --name "[KI-Test] Lage" --ort Frankfurt)  # -> LageID (Read-back-ermittelt)
edp-ctrl lage list                               # ID / aktiv|geschlossen / Name Ort
edp-ctrl lage select "$LID"                      # aktive Lage in Session setzen (Pflicht vor nachricht)
MID=$(edp-ctrl nachricht send --inhalt "…" --betreff "Info:" --von FL-1 --an ELW --empfaenger S1)
edp-ctrl lage close "$LID"                        # schließen (Adminrechte); reopen kehrt um
```

Braucht Lage-Lizenz + (für create/close/reopen) Lage-Adminrechte. `nachricht send` gibt die
neue NachrichtID aus; alle Nachrichtenfelder sind optional, `--empfaenger`/`--info` mehrfach.

## Globale Abschnittsverwaltung (`abschnittsverwaltung`, Alias `av`)

Die lageweite Abschnittsverwaltung (Seite `/html/abschnittsverwaltung`): Einsatzabschnitte
(EA) + Unterabschnitte (UA), und Einsätze/Einsatzmittel darauf verteilen. **Nicht** zu
verwechseln mit `einsatz abschnitt …` (Abschnitte _innerhalb_ eines Einsatzes, andere Tabelle).
`create-*`/`add-*` geben die neue ID aus; Read-back über
`json abschnittsverwaltung/sql/abschnitte/{abschnitt,unterabschnitt,einsatz,einsatzmittel}`.

```bash
EA=$(edp-ctrl av create-ea "1. EA Nord" --al-rufname FL-1 --taktzeichen …)
UA=$(edp-ctrl av create-ua "$EA" "UA Süd")
edp-ctrl av list                # EA;  --ua listet Unterabschnitte
ZE=$(edp-ctrl av add-einsatz "$EA" 2026999009)   # Einsatz zuordnen -> Zuordnungs-ID
ZM=$(edp-ctrl av add-em "$EA" FL-1)              # EM zuordnen -> Zuordnungs-ID
edp-ctrl av remove-einsatz "$ZE"; edp-ctrl av remove-em "$ZM"   # per Zuordnungs-ID!
edp-ctrl av edit-ea "$EA" --bezeichnung "…" --gesperrt 1        # partiell; Entsperren nur Admin
edp-ctrl av close-ua "$UA"; edp-ctrl av close-ea "$EA"
```

⚠️ `remove-einsatz`/`remove-em` erwarten die **Zuordnungs-ID** (aus add-\*/list), nicht
Einsatznummer/Rufname.

Die einsatz-interne Abschnittsebene (andere Tabelle `einsatzabschnitte`) liegt unter
`einsatz abschnitt …` (`list <enr>`, `create <enr> <bez>`, `create-ua <enr> <parent> <bez>`,
`edit <enr> <id>`, `delete <enr> <abschnittid>`, `from-vorlage <enr> <vorlage>`). Die
create-Kommandos geben **keine** ID aus — IDs über `einsatz abschnitt list <enr>`. ⚠️ `delete`
nutzt serverseitig `abschnittid` (nicht `id`); vor dem Löschen eines Hauptabschnitts erst dessen
Unterabschnitte/Einheiten entfernen.

## Dev-Toolchain (`dev`) — Build/Test/Logs/Dienste

Zur Wahl des Ausführungsmodus und zur Verifikation des Build-Ziels siehe `SKILL.md`.

```bash
edp-ctrl dev compile <projekt>        # bauen (+ Dienst-Bounce); remote zusätzlich Sync/Rückhol
edp-ctrl dev test <projekt>           # go test bzw. DUnitX, Exit-Code-gated
edp-ctrl dev log <projekt> [filter] -l Fehler   # Live-Log folgen (Ctrl-C beendet)
edp-ctrl dev service status <dienst>  # Windows-Dienst abfragen/starten/stoppen
```

Die Projekttyp-Erkennung beschreibt `dev compile --help`. Was dort nicht steht: reine
Paket-Repos wie `delphi-components` haben nur die Projektgruppe im Wurzelverzeichnis —
dort trägt `dev test`, `dev compile` hat keine Anwendung zu bauen und verweist darauf.

- **Dienst-Bounce:** der Dienst wird **auch im Fehlerfall** wieder gestartet — nie einen
  Dienst gestoppt liegen lassen. (Ohne Adminrechte kann die Dienststeuerung „Zugriff
  verweigert" liefern — dann Terminal als Administrator starten.)
- **Remote — Git ist Source-of-Truth:** `compile` verlangt einen sauberen, nicht hinter `origin`
  liegenden lokalen Baum (pusht ausstehende Commits selbst), dann VM-`reset --hard`.
- **Frontend (nur bei vorhandener `package.json`):** `compile` baut **vor dem Dienststart** auch
  das Frontend. Führt das Projekt ein **`build`**-Skript, ist das der einzige Aufruf — welche
  Schritte dazugehören, pflegt das Projekt dann selbst in seiner `package.json`. Fehlt `build`,
  fällt `compile` auf die Einzelschritte zurück: `scss:build` nach `public/css/` und
  `module:build` nach `public/module/`; der Rückfall wird protokolliert. Die Ausgaben
  sind **gitignoriert**: ein frischer Checkout und jedes VM-`reset --hard` haben sie nicht, und
  ohne den Bau laufen die `<script type="module">`-Verweise der portierten Seiten in einen
  **404 — die Seite bleibt still ohne JavaScript, während `compile` Erfolg meldet**. Die beiden
  Einzelschritte haben je eine eigene Weiche: fehlt `scss:build` bzw. `module:build` in der
  `package.json`, wird genau dieser Schritt übersprungen und `compile` bleibt grün. `build`
  dagegen kennt kein Überspringen — fehlt es, wird auf die Einzelschritte zurückgefallen.
  Übersprungen wird nie still: die Zeile steht auf der Konsole **und** im Bauprotokoll
  (`dev compilelog`) und nennt das fehlende Skript. (`dev test` baut kein Frontend.)
- **Lokal — Toolchain:** `rsvars.bat`/MSBuild werden automatisch gefunden. Auf Nicht-Windows
  ist nur `remote` möglich; `local` bricht dort mit einer klaren Fehlermeldung ab.
- **Lokal:** gebaut wird in `project-root\<projekt>` — also **im Arbeitsbaum**. `compile` verändert
  ihn dabei: eine fehlende `edpweb.ini` wird aus dem Template erzeugt, vor dem ersten wirklich
  laufenden Bauschritt bei fehlendem `node_modules` ein **`npm install` im Arbeitsbaum**, und der
  Frontend-Bau schreibt nach `public/`. Führt das Projekt keinen der drei Bauschritte, entfällt
  beides. Der Dienst-Bounce trifft den Dienst **deines eigenen Rechners**. (`dev test` macht
  davon nichts.)

## EDP-Datenbank (`db`) — nur wo es keinen HTTP-Pfad gibt

Dritte, optionale Schiene neben HTTP und Dev. Sie existiert für Daten, die **kein**
edpweb-Endpoint hergibt — heute die Schnittstellen-Konfiguration (`SCHNITTSTELLE_DEF`).
Für alles andere bleibt `action`/`json` der Weg: dort läuft die echte Server-Validierung mit.

```bash
# Einrichten (Passwort steht NIE in der Config)
edp-ctrl config set db-host <host>          # i. d. R. derselbe Host wie base-url
edp-ctrl config set db-user <benutzer>
printf '%s' '<passwort>' | edp-ctrl db ping --password-stdin   # prüft + legt im Keyring ab

edp-ctrl db ping        # Smoke-Test: Ziel (host:port/dbname) + Serverversion
edp-ctrl db forget      # hinterlegtes DB-Passwort entfernen
```

| Schlüssel    | Default | Bedeutung                                   |
| ------------ | ------- | ------------------------------------------- |
| `db-host`    | —       | Host der EDP-Datenbank                      |
| `db-port`    | `3306`  | TCP-Port                                    |
| `db-name`    | `EDPdb` | Datenbankname                               |
| `db-user`    | —       | Datenbank-Benutzer                          |
| `db-tls`     | `false` | `false`, `true`, `skip-verify`, `preferred` |
| `db-timeout` | `10s`   | Zeitgrenze für Verbindung und Abfrage       |

Alle auch per Flag (`--db-host …`) und Umgebungsvariable (`EDPCTRL_DB_HOST …`);
Präzedenz wie überall **Flag → ENV → Profil → Default** — ein **ausdrücklich leer**
übergebenes Flag (`--db-host ""`) gewinnt dabei ebenfalls und fällt _nicht_ still auf den
Profilwert zurück. Das Passwort kommt aus
`EDPCTRL_DB_PASS` oder dem OS-Keyring — dort unter einem eigenen, mit `db:` beginnenden
Eintrag, der sich mit dem edpweb-Passwort auch bei gleichem Benutzernamen nicht überschneidet.

**Fallen, die real Zeit gekostet haben:**

- **Kein TLS auf dem Server.** Viele EDP-Datenbankserver sprechen kein TLS. Steht `db-tls`
  auf `true`, meldet der Treiber nur `TLS requested but server does not support TLS` —
  `db ping` übersetzt das in eine Meldung, die auf `db-tls` zeigt.
- **Selbstsigniertes Serverzertifikat.** Verlangt der Server TLS (Fehler 3159), reicht
  `db-tls true` nicht: der Treiber prüft dann die Zertifikatskette vollständig und
  scheitert an `x509`. Weg ist `db-tls skip-verify` — verschlüsselt, aber ohne Nachweis
  der Gegenstelle. Das Gegenstück zu `insecure-tls` der HTTP-Schiene.
- **Vertippter Host hängt lange.** Ohne Zeitgrenze wartet der Treiber die Vorgabe des
  Betriebssystems ab — gegen eine nicht routbare Adresse gemessen **134 Sekunden** ohne
  jede Ausgabe. `db-timeout` begrenzt das auf 10s und deckt dabei **beides** ab:
  Verbindungsaufbau samt Anmelde-Handshake **und** Abfrage. Ein reines Wähl-Timeout
  genügte nicht — nimmt die Gegenstelle die Verbindung an und schweigt danach, ist das
  Wählen längst fertig und der Handshake hängt.
- **Fremder Dienst auf `db-port`.** Antwortet dort etwas, das kein MySQL spricht, meldet
  der Treiber nur `invalid connection`; `db ping` übersetzt das und zeigt auf `db-port`.
  Häufige Verwechslung: `db-host` wird vom `base-url` übernommen, dessen Port aber gehört
  dem Webserver.
- **Transportfehler ≠ Zeitgrenze ≠ Anmeldefehler.** Die Meldungen unterscheiden das
  ausdrücklich. Lies sie zu Ende — jede nennt Ist-Wert, Soll-Wert und das
  Behebungskommando.

> ⚠️ **`SCHNITTSTELLE_DEF.KONFIG` enthält Klartext-Zugangsdaten** (den kompletten INI-Text
> der Schnittstelle inklusive API- und Auth-Keys). Nie in eine Listenausgabe, in
> Detailausgaben nur maskiert, Klartext ausschließlich auf ausdrückliches Flag, kein Logging
> der Spalte — auch nicht im Fehlerfall.

**Einen generischen SQL-Durchgriff (`edp-ctrl sql "…"`) gibt es bewusst nicht.** Geschrieben
wird ausschließlich über eng geschnittene, typisierte Kommandos mit Read-back; lesende
Ad-hoc-Abfragen deckt der `mysql`-Client ab.

## Schnittstellen auflisten (`schnittstelle list`, Aliase `schnittstellen`, `schn`)

Läuft über die DB-Schiene oben (`db-*` müssen gesetzt sein). Der Einstieg in jede weitere
Schnittstellen-Operation — ohne die Liste ist die ID nicht bekannt.

```bash
edp-ctrl schnittstelle list           # alle konfigurierten, nach ID sortiert
edp-ctrl schnittstelle list --aktiv   # nur, was der edp:server zu DIESER Datenbank startet
edp-ctrl schnittstelle list --json    # maschinenlesbar: Rohwerte plus Label
```

```console
$ edp-ctrl schnittstelle list
ID  BESCHREIBUNG   STARTTYP     STARTPC    DATEINAME                                         TYP  LOGLEVEL      PRIO
1   IVENA          Autostart    LOCALHOST  C:\EDP\schn_ivena\Schn_IVENA.exe                  2    Server-Level  0
2   LLM            deaktiviert  LOCALHOST  C:\EDP\schn_llm\schn_llm.exe                      2    Server-Level  0
3   Feuersoftware  deaktiviert  LOCALHOST  C:\EDP\schn_feuersoftware\Schn_Feuersoftware.exe  2    Server-Level  0
```

> 🔴 **„Aktiv" ist zweiteilig, nicht einteilig.** Der edp:server-Supervisor startet nur, was
> `STARTTYP > 0` **und** `LOWER(STARTPC) = 'localhost'` erfüllt (`schnittstellenhandler.go`,
> `initSchnittstellen`). Eine Zeile mit Autostart, aber einem fremden Rechnernamen lässt er
> liegen. **Schließe niemals allein aus `STARTTYP` auf „läuft".** `--aktiv` prüft beides über
> dieselbe `WHERE`-Klausel; tritt der Fall in der ungefilterten Liste auf, weist eine
> Hinweiszeile auf stderr darauf hin.

**Für Skripte** liefert `--json` neben jedem übersetzten Feld den Rohwert — häng dich nicht an
die deutschen Wörter, die können sich ändern:

```json
{
  "id": 1,
  "typ": 2,
  "beschreibung": "IVENA",
  "dateiname": "C:\\EDP\\schn_ivena\\Schn_IVENA.exe",
  "starttyp": 1,
  "starttyp_label": "Autostart",
  "startpc": "LOCALHOST",
  "loglevel": -1,
  "loglevel_label": "Server-Level",
  "prio": 0,
  "startet_hier": true
}
```

`startet_hier` beantwortet die zweiteilige Frage fertig — **bau sie nicht nach.** Der Wert ist eine
berechnete Spalte derselben Abfrage, also vom Server aus demselben Ausdruck wie der `--aktiv`-Filter.
Eine Nachbildung driftet ab: die Kollation `utf8mb4_unicode_ci` vergleicht auf primärer
UCA-Gewichtung und zählt (gemessen auf 10.11.16-MariaDB) auch `ＬＯＣＡＬＨＯＳＴ` und `localhost`
mit angehängtem Nullbreiten-Leerzeichen als `localhost`.

```bash
# IDs aller Schnittstellen, die der edp:server hier startet
edp-ctrl schnittstelle list --json | jq -r '.[] | select(.startet_hier) | .id'
```

**Feld-Eigenheiten, die sonst Zeit kosten:**

- **`STARTTYP` als Wort:** `Autostart` (1), `deaktiviert` (0), `manuell` (-1). Auch `-1` ist ein
  **dokumentierter** Wert — nicht als Fehler lesen.
- **`LOGLEVEL -1` = `Server-Level`** („Log-Level des Servers übernehmen", laut DDL). Jedes echte
  Log-Level bleibt die Zahl.
- **`TYP` bleibt eine Zahl** (laut DDL 0 = undefiniert, 1 = Funk-Schnittstelle, 2 = Ansteuerung).
  `edpkonfig` schreibt beim Anlegen hart `0`, die gemessenen Zeilen tragen trotzdem `2`, und im
  Supervisor steht am Feld ein offener Prüfauftrag. **Keine Auswahl- oder Filterlogik darauf
  bauen** — und ein Wort erwarten schon gar nicht.
- **Leer ist kein Fehler** (Exit-Code 0, `--json` liefert `[]`). Die Meldung unterscheidet
  „nichts konfiguriert" von „nichts, was hier startet".
- **Die Tabelle ist für Menschen, `--json` für Skripte.** Tabulator, Zeilenumbruch und CR in einem
  Feldwert werden in der Tabelle zu Leerzeichen — sonst zerlegte eine solche Zeile die ganze
  Ausgabe. `--json` liefert den Wert unverändert.
- **`KONFIG` erscheint nirgends** — die Spalte wird nicht einmal gelesen. Sie enthält
  Klartext-Zugangsdaten; ein eigenes Kommando mit Maskierung kommt später.

> ⚠️ Der Supervisor liest die Definitionen **einmal beim Start** des edp:server. Eine Änderung an
> der Tabelle wirkt erst nach einem Serverneustart; eine Laufzeit-Steuerung gibt es nicht.

## Schnittstelle aktivieren/deaktivieren (`schnittstelle enable|disable`)

Setzt `STARTTYP` — dieselbe Spalte, die auch die beiden Schaltflächen in `edpkonfig` setzen.

```bash
edp-ctrl schnittstelle enable 2             # STARTTYP = 1  (Autostart)
edp-ctrl schnittstelle enable 2 --manuell   # STARTTYP = -1 (nur manueller Start)
edp-ctrl schnittstelle disable 2            # STARTTYP = 0
edp-ctrl schnittstelle enable LLM           # Auflösung auch über die BESCHREIBUNG
```

```console
$ edp-ctrl schnittstelle enable 2
Ziel: 172.16.0.2:3306/EDPdb [Profil devvm]
  ID 2  LLM  —  deaktiviert, STARTPC LOCALHOST

STARTTYP 0 (deaktiviert) → 1 (Autostart)
Read-back: ID 2  LLM  —  Autostart, STARTPC LOCALHOST
Hinweis: der edp:server liest die Schnittstellenliste einmal beim Start.
  Die Aenderung wirkt erst nach einem Neustart des edp:server.
```

> 🔴 **`enable` wirkt nach außen.** Eine aktivierte Schnittstelle nimmt beim nächsten Serverstart
> Verbindung zu einem **Fremdsystem** auf (Leitstellen-, Alarmierungs- oder Herstellersysteme) —
> gegen eine Produktivinstallation ist das keine reine Konfigurationsänderung. **Lies die erste
> Ausgabezeile**: sie nennt die Datenbank, auf die das Profil zeigt. Eine interaktive Rückfrage
> gibt es bewusst nicht (sie würde in Skripten hängen); die Sichtbarkeit des Ziels tritt an ihre
> Stelle. Sie steht **vor** dem Schreibzugriff da, ist also auch bei einem Abbruch protokolliert.

**Zielangabe:**

- **Rein numerisch = IMMER die ID**, nie die Beschreibung. Heißt eine Schnittstelle wirklich
  `42`, ist sie ausschließlich über ihre ID auswählbar — die Fehlermeldung sagt das dazu.
- Sonst **exakter Vergleich** auf `BESCHREIBUNG`, kein Teiltreffer: `IVEN` wählt nichts aus.
- **Unbekannt oder mehrdeutig → Exit ≠ 0 und kein Schreibzugriff.** Die Meldung nennt bei
  Mehrdeutigkeit alle Treffer mit ID und schließt mit „Es wurde nichts geschrieben." — daran
  erkennst du, dass ein korrigierter Aufruf gefahrlos ist.

> ⚠️ **Die Beschreibung vergleicht der SERVER, nicht das Werkzeug** — mit seiner Kollation.
> Gemessen auf 10.11.16-MariaDB (`BESCHREIBUNG` ist `utf8mb4_unicode_ci`): `WHERE beschreibung =
'ivena'` trifft die Zeile `IVENA`. **Ein `enable ivena` schaltet also die Zeile `IVENA`** — die
> Auswahl ist unabhängig von der Groß-/Kleinschreibung, obwohl ein Zeichenvergleich das anders
> sähe. Umgekehrt gilt: gibt es zwei Zeilen, die der Server für gleich hält, lehnt das Kommando
> ab, statt eine davon zu raten.

**Read-back und Fehlerbilder** — das Kommando liest die Zeile nach dem `UPDATE` erneut und prüft
sie gegen die Absicht. Regel 5 ist damit erfüllt, du musst nicht selbst nachlesen.

🔑 **Das eine Merkmal, an dem du die Fälle auseinanderhältst:** jede Meldung, die nach dem
Absetzen des `UPDATE` entsteht, beginnt mit **`das UPDATE wurde abgesetzt —`**. Jede Meldung
davor endet mit **`Es wurde nichts geschrieben.`** Danach richtest du dich, nicht nach dem
Wortlaut des Rests.

| Ausgang                                       | Bedeutung                                                             | Was du tun musst                                         |
| --------------------------------------------- | --------------------------------------------------------------------- | -------------------------------------------------------- |
| `STARTTYP … → …` + `Read-back:`               | geschrieben und bestätigt                                             | nichts                                                   |
| `Steht bereits auf …`                         | war schon im Zielzustand, **kein** Schreibzugriff, Exit 0             | nichts — das ist kein Fehler                             |
| `… Es wurde nichts geschrieben.`              | Ziel unbekannt, mehrdeutig oder leer — die DB wurde nicht angefasst   | Aufruf korrigieren und gefahrlos wiederholen             |
| `das UPDATE wurde abgesetzt — … UNBESTAETIGT` | geschrieben, Zustand **unbekannt** (Schreib-/Lesefehler, Zeile weg)   | `schnittstelle list` fahren, **nicht** blind wiederholen |
| `das UPDATE wurde abgesetzt — … widerspricht` | geschrieben, Zustand **bekannt falsch** (jemand schrieb gleichzeitig) | `schnittstelle list` fahren, dann gezielt nachsteuern    |

⚠️ Die letzten beiden trennt eine echte Unterscheidung: bei `UNBESTAETIGT` weißt du **nicht**, was
in der Zeile steht; beim Widerspruch weißt du es — es ist nur nicht das Gewollte. Gemeinsam ist
beiden, dass geschrieben **wurde**. Ein blindes Wiederholen ist deshalb in beiden Fällen die
teuerste Reaktion.

**Weitere Eigenheiten:**

- **Genau eine Spalte** wird geschrieben (`SET starttyp = ? WHERE id = ?`, parametrisiert).
  `edpkonfig` schreibt an derselben Stelle `BESCHREIBUNG` und `DATEINAME` mit — dem folgt die CLI
  bewusst nicht.
- **Kein `--all`, keine Muster.** Mehrere Schnittstellen schaltest du einzeln.
- Nach einem `enable` auf **fremdem `STARTPC`** kommt eine Warnung auf stderr: der edp:server zu
  dieser Datenbank startet die Zeile trotzdem nicht. **Lies sie** — sonst meldest du eine
  Schnittstelle als künftig laufend, die es nie sein wird.
- **`--manuell` gibt es nur bei `enable`** (`STARTTYP = -1` deaktiviert ja gerade nicht).

> ⚠️ **Der laufende Prozess wird nicht angefasst.** `disable` beendet keine laufende Schnittstelle
> und `enable` startet keine — der Supervisor baut seine Prozessliste einmal beim Start, eine
> Laufzeit-Steuerung gibt es nicht (`stopSchnittstelle` ist dort noch nicht angebunden). **Sag beim
> Melden einer Änderung dazu, dass sie erst nach einem Neustart des edp:server greift.**

---
name: edp-ctrl
description: CLI zum Interagieren mit EDP (edpweb) — Anmelden, Aktionen/Abfragen gegen einen edpweb-Server sowie (optional) Kompilieren, Logs und Dienste, wahlweise auf einer Dev-VM (SSH) oder lokal auf einem Windows-Rechner gegen die installierte Toolchain. Use when an agent needs to log into edpweb, trigger actions, query data, reproduce a bug, test a feature, or build/run an EDP project via the `edp-ctrl` command.
allowed-tools: Bash(edp-ctrl:*)
---

# edp-ctrl

`edp-ctrl` ist ein CLI, mit dem du (als Agent) mit EDP interagierst — vor allem, um
**Bugs zu reproduzieren und Features zu testen**, ohne mit `curl`/SSH von Hand zu
hantieren.

Zwei Schienen:

- **HTTP** (edpweb): anmelden, Aktionen auslösen, Daten abfragen. Braucht nur
  HTTPS-Erreichbarkeit eines edpweb-Servers.
- **Dev** (optional): kompilieren, Logs streamen, Dienste steuern — remote (SSH zur
  Dev-VM) oder lokal.

## Maßgebliche Quelle: `--help`

Der **aktuelle** Kommando-Umfang ist immer über die eingebaute Hilfe abrufbar — sie ist
per Definition synchron zur installierten Version:

```bash
edp-ctrl --help              # alle Kommandogruppen
edp-ctrl <gruppe> --help     # z.B. edp-ctrl action --help
```

> ⚠️ Dieser Skill wächst mit dem Tool. Wenn ein hier beschriebenes Kommando von
> `--help` abweicht, **gilt `--help`**. Bei „VERALTET" in `edp-ctrl skills status`:
> `edp-ctrl skills install` (oder `edp-ctrl update`) ausführen.

## Aufbaustand

`edp-ctrl` wird phasenweise entwickelt. Verlass dich auf `--help` für das, was *jetzt*
verfügbar ist. Verfügbar: `config` (Profile), `auth` (Anmelden), `action`/`json`
(Aktionen & Abfragen), `einsatz` (typisierte Wrapper inkl. EM-Dispo & ETB), `em`
(Einsatzmittel steuern), `lage` (Lageführung/ELW), `nachricht` (ELW-Nachrichten),
`abschnittsverwaltung`/`av` (globale Abschnittsverwaltung), `dev` (compile/test/log/service),
`skills`, `update` (Self-Update).

### Erste Schritte

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

### Aktionen auslösen & Daten abfragen (`action` / `json`)

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

- **Reproduzier-Muster für Bugs/Features:** Einsatz via `action einsatz/saveeinsatz …
  target=einsatznummer` anlegen (gibt die Einsatznummer aus), Zustand mutieren, dann per
  `json …` **zurücklesen** (Regel 5). Endpoints/Parameter/Footguns stehen in der
  edpweb-Testing-Referenz (`actions-einsatz` etc.).
- **Fehler** kommen als lesbare Zeile `Fehler: HTTP <code>: <meldung>` (Exit-Code ≠ 0);
  ein leerer Erfolgs-Body erzeugt keine Ausgabe (Exit-Code 0).

### Typisierte Einsatz-Wrapper (`einsatz`)

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

### Einsatzmittel steuern (`em`)

Stammaktionen an Einsatzmitteln (unabhängig vom Buchen auf einen Einsatz). Read-back über
die EM-Liste (`json einsatz/sql/einsatzmittel einsatznummer=<enr>` bzw. `json map/einsatzmittel`).

```bash
edp-ctrl em setstatus FL-1 3                     # FMS-Status 0..9 (client-seitig geprüft)
edp-ctrl em edit FL-1 --besatzung-ges 6 --auftrag "…" --abschnitt -1   # nur gesetzte Felder
edp-ctrl em setpos FL-1 --koordx 8.6821 --koordy 50.1109               # beide zusammen setzen
edp-ctrl em setpos FL-1                          # ⚠️ ohne Koordinaten LÖSCHT der Server die Position
```

### Lageführung / ELW (`lage`, `nachricht`)

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

### Globale Abschnittsverwaltung (`abschnittsverwaltung`, Alias `av`)

Die lageweite Abschnittsverwaltung (Seite `/html/abschnittsverwaltung`): Einsatzabschnitte
(EA) + Unterabschnitte (UA), und Einsätze/Einsatzmittel darauf verteilen. **Nicht** zu
verwechseln mit `einsatz abschnitt …` (Abschnitte *innerhalb* eines Einsatzes, andere Tabelle).
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

⚠️ `remove-einsatz`/`remove-em` erwarten die **Zuordnungs-ID** (aus add-*/list), nicht
Einsatznummer/Rufname.

Die einsatz-interne Abschnittsebene (andere Tabelle `einsatzabschnitte`) liegt unter
`einsatz abschnitt …` (`list <enr>`, `create <enr> <bez>`, `create-ua <enr> <parent> <bez>`,
`edit <enr> <id>`, `delete <enr> <abschnittid>`, `from-vorlage <enr> <vorlage>`). Die
create-Kommandos geben **keine** ID aus — IDs über `einsatz abschnitt list <enr>`. ⚠️ `delete`
nutzt serverseitig `abschnittid` (nicht `id`); vor dem Löschen eines Hauptabschnitts erst dessen
Unterabschnitte/Einheiten entfernen.

### Dev-Toolchain (`dev`) — Build/Test/Logs/Dienste

Projekttyp automatisch (`.dproj` **oder** `.groupproj` = Delphi/MSBuild, `go.mod` = Go —
reine Paket-Repos wie `delphi-components` haben nur die Projektgruppe im Wurzelverzeichnis;
dort trägt `dev test`, `dev compile` hat keine Anwendung zu bauen und verweist darauf).
Zwei Ausführungsmodi, gesteuert über den Schlüssel `executor` (`auto`|`local`|`remote`,
Default `auto`):

- **remote** (braucht `vm-host`, SSH zur Dev-VM): commit/push → VM-Sync → Build → EXE holen.
- **local** (nur Windows): baut **in-place im lokalen Arbeitsbaum** gegen die lokal
  installierte Toolchain — kein Git-Push, kein VM-Sync, kein EXE-Rückhol, uncommittete
  Änderungen inklusive. `rsvars.bat`/MSBuild werden automatisch gefunden.

`auto` wählt remote, sobald `vm-host` gesetzt ist, sonst local. Auf Nicht-Windows ist nur
remote möglich (klare Fehlermeldung sonst).

> ⚠️ **`--executor local` erzwingt lokal — auch wenn `vm-host` gesetzt ist.** Nur `auto`
> richtet sich nach `vm-host`.
>
> **Wenn du auf der VM bauen willst, setz `--executor remote` explizit** statt dich auf
> `auto` zu verlassen — sonst baust du auf einem Windows-Rechner ohne konfigurierten
> `vm-host` still lokal. Und **verifizier das Ziel an der Ausgabe**: die erste Zeile lautet
> `=== Kompiliere <projekt> auf <ziel> ===`, wobei `<ziel>` entweder der `vm-host` oder
> `lokal` ist. Passt das nicht zur Absicht, brich ab und korrigier den Modus.

```bash
edp-ctrl dev compile <projekt>        # bauen (+ Dienst-Bounce); remote zusätzlich Sync/Rückhol
edp-ctrl dev test <projekt>           # go test bzw. DUnitX, Exit-Code-gated
edp-ctrl dev log <projekt> [filter] -l Fehler   # Live-Log folgen (Ctrl-C beendet)
edp-ctrl dev service status <dienst>  # Windows-Dienst abfragen/starten/stoppen
```

- **Dienst-Bounce:** ein zugehöriger Windows-Dienst wird um den Build gestoppt und **auch
  im Fehlerfall** wieder gestartet — nie einen Dienst gestoppt liegen lassen. (Ohne Adminrechte
  kann die Dienststeuerung „Zugriff verweigert" liefern — dann Terminal als Administrator starten.)
- **Remote — Git ist Source-of-Truth:** `compile` verlangt einen sauberen, nicht hinter `origin`
  liegenden lokalen Baum (pusht ausstehende Commits selbst), dann VM-`reset --hard`.
- **Lokal:** gebaut wird in `project-root\<projekt>` — also **im Arbeitsbaum**. `compile` verändert
  ihn dabei: eine fehlende `edpweb.ini` wird aus dem Template erzeugt, und bei `package.json` ohne
  `node_modules` läuft ein **`npm install` im Arbeitsbaum**. Der Dienst-Bounce trifft den Dienst
  **deines eigenen Rechners**. (`dev test` macht diese drei Schritte nicht.)
- **Lokal — fehlende Redist-DLLs:** `libcrypto-3-x64.dll`/`libssl-3-x64.dll`/`libmariadb.dll` liegen
  bewusst nicht im Git und werden lokal **nicht** bereitgestellt. Auf einem frischen Checkout fehlen
  sie; `compile`/`test` geben dann eine `WARNUNG:`-Zeile mit Download-Kommando aus. **Nimm diese
  Warnung ernst:** der Build meldet Erfolg, aber die EXE startet nicht — `dev test` bricht mit
  **Exit 53 ohne jede Ausgabe** ab. Such den Fehler dann nicht im Code, sondern hol die DLLs.

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

## Skill-Verwaltung

```bash
edp-ctrl skills install            # Skill nach ~/.claude/skills/edp-ctrl installieren
edp-ctrl skills install --local    # stattdessen ./.claude/skills/edp-ctrl (projektlokal)
edp-ctrl skills install --agents   # zusätzlich ./.agents/skills/edp-ctrl (forward-compat)
edp-ctrl skills status             # installierte vs. CLI-Version (Drift-Check)
edp-ctrl update                    # Binary aktualisieren + Skill neu installieren
```

Der Skill ist ins `edp-ctrl`-Binary eingebettet und damit immer zur CLI-Version passend.
**Nicht am Installationsort editieren** — Quelle ist das Repo/Binary. `edp-ctrl update`
aktualisiert Binary und Skill gemeinsam (kein Drift). Bei „VERALTET" in `skills status`
genügt `edp-ctrl skills install` bzw. `edp-ctrl update`.

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
  das Frontend — `scss:build` nach `public/css/` und, falls das Projekt ein `module:build`-Skript
  führt, die Modul-Kompilate nach `public/module/`. Beides sind **gitignore-Ausgaben**: ein
  frischer Checkout und jedes VM-`reset --hard` haben sie nicht, und ohne den Bau laufen die
  `<script type="module">`-Verweise der portierten Seiten in einen **404 — die Seite bleibt still
  ohne JavaScript, während `compile` Erfolg meldet**. Führt ein Projekt kein `module:build`, wird
  nur dieser Schritt übersprungen und das protokolliert; `compile` bleibt grün. (`dev test` baut
  kein Frontend.)
- **Lokal — Toolchain:** `rsvars.bat`/MSBuild werden automatisch gefunden. Auf Nicht-Windows
  ist nur `remote` möglich; `local` bricht dort mit einer klaren Fehlermeldung ab.
- **Lokal:** gebaut wird in `project-root\<projekt>` — also **im Arbeitsbaum**. `compile` verändert
  ihn dabei: eine fehlende `edpweb.ini` wird aus dem Template erzeugt, bei `package.json` ohne
  `node_modules` läuft ein **`npm install` im Arbeitsbaum**, und der Frontend-Bau schreibt nach
  `public/`. Der Dienst-Bounce trifft den Dienst **deines eigenen Rechners**. (`dev test` macht
  davon nichts.)

---
name: edp-ctrl
description: CLI zum Interagieren mit EDP (edpweb) — Anmelden, Aktionen/Abfragen gegen einen edpweb-Server sowie (optional) Kompilieren, Logs und Dienste auf einer Dev-VM. Use when an agent needs to log into edpweb, trigger actions, query data, reproduce a bug, test a feature, or build/run an EDP project via the `edp-ctrl` command.
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
(Aktionen & Abfragen), `einsatz` (typisierte Wrapper), `dev` (compile/test/log/service),
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
edp-ctrl action einsatz/saveeinsatz MELDUNG="[Jarvis-Test] Demo" STICHWORT=H1 target=einsatznummer
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
        --meldung "[Jarvis-Test] Demo" --stichwort H1 --einsatzart THL)

edp-ctrl einsatz show "$ENR"               # Read-back (Status/Ort/Meldung) — Regel 5
edp-ctrl einsatz setstatus "$ENR" Beendet  # Erfasst|Disponiert|Alarmiert|Beendet|Unwetter
edp-ctrl einsatz close "$ENR"              # endgültig schließen
```

Der Status wird schon **client-seitig** gegen die Whitelist geprüft (kein Fehlversuch
gegen den Server); weitere `saveeinsatz`-Felder gehen bei `create` per `--param key=value`.

### Dev-Toolchain (`dev`) — Build/Test/Logs/Dienste auf der Dev-VM

Optional, braucht `vm-host` im Profil (SSH zur Dev-VM). Projekttyp automatisch (`.dproj`
= Delphi/MSBuild, `go.mod` = Go). Ersetzt das alte `edp()`-Shell-Gefummel.

```bash
edp-ctrl dev compile <projekt>        # commit/push → VM-Sync → Build → EXE holen (+ Dienst-Bounce)
edp-ctrl dev test <projekt>           # go test bzw. DUnitX, Exit-Code-gated
edp-ctrl dev log <projekt> [filter] -l Fehler   # Live-Log folgen (Ctrl-C beendet)
edp-ctrl dev service status <dienst>  # Windows-Dienst abfragen/starten/stoppen
```

- **Git ist Source-of-Truth:** `compile` verlangt einen sauberen, nicht hinter `origin`
  liegenden lokalen Baum (pusht ausstehende Commits selbst), dann VM-`reset --hard`.
- **Dienst-Bounce:** ein zugehöriger Windows-Dienst wird um den Build gestoppt und **auch
  im Fehlerfall** wieder gestartet — nie einen Dienst gestoppt liegen lassen.

## Verbindliche Regeln (zeitlos — immer beachten)

Diese gelten unabhängig vom Kommando-Umfang. Details in
[references/fallen.md](references/fallen.md).

1. **Nur gegen Test-/Dev-Instanzen arbeiten, NIE gegen die Kunden-Demo.** Schreibende
   Aktionen (Einsatz anlegen, Status setzen) laufen ausschließlich gegen eine dafür
   vorgesehene Instanz (Tims Dev-VM / persönliche Instanz), **niemals** gegen
   `demo.edpweb.de` — dort sehen echte Kunden die Daten.
2. **Keine Emojis / 4-Byte-Zeichen in Freitextfeldern** (Meldung, Bemerkung …). Der
   Server verschluckt sie (`?`). Marker wie `[KI]`, `[BOT]`, `[Jarvis-Test]` verwenden.
3. **Testdaten kennzeichnen** (Präfix `Jarvis-Test`) und **reservierte
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

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
  HTTPS-Erreichbarkeit eines edpweb-Servers. Generischer Durchgriff auf jeden Endpoint
  über `json` (lesend) und `action` (mutierend), daneben typisierte Wrapper für den
  Alltagspfad.
- **Dev** (optional): kompilieren, Logs streamen, Dienste steuern — remote (SSH zur
  Dev-VM) oder lokal.

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

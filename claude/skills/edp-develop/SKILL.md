---
name: edp-develop
description: This skill should be used when the user asks to compile or build an EDP project, start/stop/status a Windows service, or stream logs on the EDP dev VM. Covers the EDP-specific dev workflow driven by the `edp-ctrl dev` CLI.
user-invocable: false
---

# EDP Development Tools

Der EDP-Entwicklungs-Workflow läuft über die **`edp-ctrl dev`**-Schiene — ein Go-CLI,
das Kompilieren, Testen, Logs und Windows-Dienste auf der Dev-VM (SSH) steuert. Diese
Skill beschreibt den EDP-spezifischen Workflow und die VM-Umgebung; die maßgebliche,
stets aktuelle Kommando-Referenz ist `edp-ctrl dev --help` bzw. die mitgelieferte
`edp-ctrl`-Skill.

> Diese Schiene hat die frühere `edp()`-Shell-Funktion abgelöst. Alte Muskelgedächtnis-
> Zuordnung: `edp <projekt> compile` → `edp-ctrl dev compile <projekt>`.

## Kommandos

```bash
edp-ctrl dev compile <projekt> [-b] [--platform Win64] [--config Release] [--service <svc>]
edp-ctrl dev test    <projekt>
edp-ctrl dev log     <projekt> [filter] [-l <LEVEL>]
edp-ctrl dev compilelog <projekt>

# Dienste (ohne Projekt)
edp-ctrl dev service start  <service>
edp-ctrl dev service stop   <service>
edp-ctrl dev service status <service>
```

Host, Projektpfade und Delphi-Toolchain kommen aus dem **aktiven Profil**
(`edp-ctrl config`), lassen sich aber pro Aufruf per Flag überschreiben
(`--vm-host`, `--project-root`, `--vm-dir-base`, `--rsvars`, `--msbuild`).

## Architektur

- **Git ist die einzige Source of Truth.** Der einzige Transportweg zur VM ist
  `edp-ctrl dev compile`: lokale Commits werden auto-gepusht, die VM pullt
  `origin/<current-branch>` (`reset --hard`) und baut daraus. Kein tar-over-SSH, kein
  nicht-committeter Stand auf der VM — jede EXE ist reproduzierbar an einen Commit-SHA
  gebunden.
- **Dienst-Bounce um den Build.** Ein zugehöriger Windows-Dienst wird vor dem Build
  gestoppt und **auch im Fehlerfall** wieder gestartet (nie einen Dienst gestoppt liegen
  lassen). Das Mapping ist als Heuristik eingebaut, per `--service` überschreibbar.

### Warum nur git-transport

- Jede gebaute EXE ist an einen konkreten Commit gebunden (Reproduzierbarkeit).
- "Was läuft gerade auf der VM?" ist immer ein bekannter SHA — `git log -1` auf der VM genügt.
- Passt zum Feature-Branch-Workflow: iterieren mit WIP-Commits (`git commit --amend`), am Ende squash-mergen.
- Kein stummes Auseinanderlaufen zwischen lokalem Working Tree und gebauter EXE.

### Compile-Voraussetzungen

- Lokales Projektverzeichnis muss ein Git-Repo mit `origin`-Remote sein.
- Working tree muss sauber sein (uncommittete Änderungen → `compile` verweigert).
- Branch darf nicht hinter `origin/<branch>` sein (divergente History → verweigert).
- Branch ahead of remote → wird auto-gepusht.
- Die VM muss gegen `origin` authentifizieren können. Für GHE über HTTPS, einmal pro VM konfigurieren:
  ```cmd
  git config --global --unset-all credential.helper
  git config --global --add credential.helper ""
  git config --global --add credential.helper store
  ```
  Dann eine Zeile wie `https://<user>:<token>@einsatzleitsoftware.ghe.com` in
  `%USERPROFILE%\.git-credentials` schreiben (UTF-8, no BOM — PowerShells default
  `Set-Content` schreibt UTF-16 BOM; stattdessen `[IO.File]::WriteAllText(...)` oder
  `Out-File -Encoding utf8NoBOM`).

## Dienste

Windows-Dienste werden **manuell** vom Nutzer installiert — das Build-System **legt nie
Dienste an** (`sc create` o.ä.). Jedes Projekt ist auf den einen Dienst gemappt, der
seine EXE offen hält; nur dieser wird um den Build gestoppt/gestartet:

| Projektname                    | Dienst          |
|--------------------------------|-----------------|
| `edpweb`                       | `edpwebservice` |
| `schn_*` (alle Schnittstellen) | `EDPSrv`        |
| `server`                       | `EDPSrv`        |
| alles andere                   | (keiner — kein Bounce; per `--service` erzwingbar) |

Einzelne Dienste lassen sich auch manuell mit `edp-ctrl dev service start|stop|status <service>` steuern.

## Compile (git-transport)

**Projekttyp wird automatisch erkannt:** `.dproj` im Root → Delphi (MSBuild), `go.mod` im
Root → Go (`go build`). Weder noch → Fehler.

### Delphi-Pipeline

1. `.dproj` im Projektverzeichnis auto-detecten (genau 1 muss existieren)
2. Git-Prep (lokal): verweigert bei dirty/behind; auto-push wenn ahead
3. Zugehörigen Dienst stoppen (falls gemappt)
4. Git-Sync auf VM:
   - Erstmalig: `<vm-dir-base>\<projekt>\` leeren und `git clone --branch <branch> <origin-url>`
   - Danach: `git fetch && git checkout -B <branch> origin/<branch> && git reset --hard origin/<branch>`
   - Untracked Build-Outputs (`Win64/`, `*.dcu`, `node_modules/`) bleiben → inkrementelle Rebuilds bleiben schnell
5. SCSS-Build auf VM (nur wenn `package.json` im Root):
   - Falls `node_modules\` fehlt: `npm install` (einmalig, persistiert)
   - `npm run scss:build` → kompiliert SCSS nach `public/css/**/*.min.css`
   - `edpweb` nutzt das; Projekte ohne `package.json` überspringen den Schritt transparent
6. MSBuild via SSH (direkter Aufruf — **kein** per-Projekt-`compile.cmd`):
   ```cmd
   call "<rsvars.bat>" && cd /d <vm-dir-base>\<projekt> && ^
   <MSBuild.exe> <Project>.dproj /t:Make /p:config=Release /p:platform=Win64
   ```
   (`-b` → `/t:Build` statt `/t:Make`; `--platform`/`--config` überschreiben Win64/Release)
7. Gebautes EXE per scp zurück ins lokale Projektverzeichnis holen
8. Dienst wieder starten (falls gemappt)

### Go-Pipeline

Für Projekte mit `go.mod` im Root:

1. Git-Prep (wie Delphi: clean + auto-push)
2. Dienst-Stop (gleiches Mapping — Libraries ohne Dienst überspringen den Schritt)
3. Git-Sync auf VM
4. `go build ./...` — muss fehlerfrei durchlaufen
5. Wenn `main.go` im Repo-Root existiert (= Schnittstelle, keine reine Library):
   - `go build -ldflags="-s -w -H=windowsgui" -o <projekt>.exe .` (`-H=windowsgui` unterdrückt
     das CMD-Fenster, so verhalten sich Go-Schnittstellen wie die Delphi-GUI-Apps)
   - `<projekt>.exe` per scp zurück ins lokale Verzeichnis
6. Dienst-Start (falls gemappt)

Reine Library-Projekte (keine `main.go`) überspringen Schritt 5 — kein EXE-Artefakt.
Tests laufen separat über `edp-ctrl dev test <projekt>` (`go test ./...`), nicht als Teil
von `compile`.

Voraussetzung auf der VM: Go installiert, `go` im `PATH` der SSH-Session.

## Branch-Protection

`main`/`dev` auf GHE verlangen PRs — direkte Pushes scheitern. **Immer auf einem
Feature-Branch arbeiten.** Der Auto-Push in `compile` pusht den aktuellen Branch; auf
`main` lehnt GHE ab. Vor dem Iterieren `git checkout -b feature/xyz`.

### Iterativ-Dev-Rezept

```bash
git checkout -b fix/something
git commit -am "wip"                 # erster Versuch
edp-ctrl dev compile schn_foo        # auto-push Feature-Branch + Build auf VM
# ...Fehler fixen...
git commit -a --amend --no-edit
git push --force-with-lease          # oder den Helper neu pushen lassen (verweigert behind)
edp-ctrl dev compile schn_foo
# ...fertig → PR, squash-merge
```

## VM-Konfiguration

- **SSH-Host / Projektpfade / Toolchain** kommen aus dem `edp-ctrl`-Profil (`vm-host`,
  `project-root`, `vm-dir-base`, `rsvars`, `msbuild`).
- **VM-OS**: Windows 11 24H2
- **Delphi**: RAD Studio 13.1 Florence (BDS `37.0`), `C:\Program Files (x86)\Embarcadero\Studio\37.0\`
- **rsvars.bat**: `C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat`
- **MSBuild**: `C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe` (.NET Framework v4.5)
- **Node.js / npm**: `C:\Program Files\nodejs\` — für den SCSS-Build (Dart Sass)
- **Projekt-Root auf VM**: `<vm-dir-base>\<projekt>` (Default `C:\EDP\`; ein Verzeichnis pro
  Projekt; geteilte Libraries wie `jvcl`, `jcl`, `DelphiComponents`, `Image32`,
  `komponenten_delphi`, `HtmlViewer`, `ComPort-Library`, `StyleControls`,
  `SVGIconImageList`, `SynPDF`, `ELP`, `tzgenerator` liegen direkt unter `C:\EDP\`)

## Neues Projekt aufnehmen

1. Genau ein `.dproj` im Projekt-Root sicherstellen (auto-detected) — oder `go.mod` für Go.
2. Projekt muss ein Git-Repo mit `origin` auf GHE sein, das die VM erreichen kann
   (HTTPS-Credentials wie oben).
3. Soll es ein Windows-Dienst sein: **Dienst manuell installieren** — das Build-System
   berührt nie die Dienst-Registrierung, nur Start/Stop.
4. Ist der Dienst kein Default (`edpwebservice` für `edpweb`, `EDPSrv` für `schn_*`/`server`),
   ihn per `--service <dienst>` an `compile` übergeben.
5. Erster `edp-ctrl dev compile <projekt>` klont automatisch nach `<vm-dir-base>\<projekt>\`.
6. **Nur bei Migration Delphi → Go**: ggf. alte `<ProjektCased>.exe` auf der VM einmal
   entfernen (siehe Troubleshooting), sonst scheitert der erste Go-Build.

## Troubleshooting

### Go-Build: "build output <exe> already exists and is not an object file"

Tritt auf, wenn auf der VM noch eine EXE aus einer früheren Build-Ära (typisch: Delphi vor
Migration zu Go) liegt und sich der Case des Dateinamens vom Go-Output unterscheidet.
Windows ist case-insensitive, Go erkennt die Datei nicht als eigenen Build-Output und
verweigert das Überschreiben. Einmalig entfernen:

```bash
ssh <vm-host> "del <vm-dir-base>\\<projekt>\\<AlterName>.exe"
```

Beispiel (beim `schn_ollama`-Delphi→Go-Wechsel): `del C:\EDP\schn_ollama\Schn_Ollama.exe`.

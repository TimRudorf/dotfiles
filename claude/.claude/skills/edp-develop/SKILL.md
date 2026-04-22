---
name: edp-develop
description: This skill should be used when the user asks to compile or build an EDP project, start/stop/status a Windows service, stream logs, or mentions the edp() shell function.
user-invocable: false
---

# EDP Development Tools

Documentation for the `edp()` shell function (`~/.edp_helpers.sh`) — central tool for building and managing all EDP projects on the Windows dev VM.

## Architecture

- **Git ist die einzige Source of Truth.** Der einzige Transportweg zur VM ist `edp <project> compile`: lokale Commits werden auto-gepusht, die VM pullt `origin/<current-branch>` und baut daraus.
- **`deploy` wurde entfernt.** Der frühere tar-over-SSH-Pfad existiert nicht mehr — er erlaubte nicht-committeten lokalen Stand auf der VM und hat Drift zwischen Arbeitskopie und EXE ermöglicht. Jeder Build ist jetzt reproduzierbar an einen Commit-SHA gebunden. Ruft jemand `edp <project> deploy` auf, gibt `edp()` eine Fehlermeldung aus und verweist auf `compile`.
- Services werden pro Projekt gestoppt/gestartet (Mapping in `_edp_service_for_project`).

### Warum nur noch git-transport

- Jede gebaute EXE ist an einen konkreten Commit gebunden (Reproduzierbarkeit).
- "Was läuft gerade auf der VM?" ist immer ein bekannter SHA — `git log -1` auf der VM genügt.
- Passt natürlich zum Feature-Branch-Workflow: iterieren mit WIP-Commits (`git commit --amend` zwischen Versuchen), am Ende squash-mergen.
- Kein stummes Auseinanderlaufen zwischen lokalem Working Tree und gebauter EXE.

### Compile prerequisites

- Lokales Projektverzeichnis muss ein Git-Repo mit `origin`-Remote sein.
- Working tree muss sauber sein (uncommittete Änderungen → `edp compile` verweigert).
- Branch darf nicht hinter `origin/<branch>` sein (divergente History → verweigert).
- Branch ahead of remote → wird auto-gepusht.
- VM muss gegen `origin` authentifizieren können. Für GHE über HTTPS, einmal pro VM konfigurieren:
  ```cmd
  git config --global --unset-all credential.helper
  git config --global --add credential.helper ""
  git config --global --add credential.helper store
  ```
  Dann eine Zeile wie `https://<user>:<token>@einsatzleitsoftware.ghe.com` in `%USERPROFILE%\.git-credentials` schreiben (UTF-8, no BOM — PowerShells default `Set-Content` schreibt UTF-16 BOM; stattdessen `[IO.File]::WriteAllText(...)` oder `Out-File -Encoding utf8NoBOM`).

## Usage

```bash
# Project commands
edp <project> compile [host] [-b] [-p:...] [-cfg:...]
edp <project> log [filter] [-l=LEVEL]
edp <project> compilelog

# Service commands (no project needed)
edp start <service> [host]
edp stop <service> [host]
edp status <service> [host]
```

### Services

Windows services are **installed manually** by the user — the build system **never creates services** via `sc create` or similar.

Each project is mapped to the single Windows service that holds its EXE open; that service (and only that service) is stopped before compile and restarted afterwards. The mapping lives in `_edp_service_for_project` in `~/.edp_helpers.sh`:

| Project name               | Service         |
|----------------------------|-----------------|
| `edpweb`                   | `edpwebservice` |
| `schn_*` (alle Schnittstellen) | `EDPSrv`    |
| `server`                   | `EDPSrv`        |
| everything else            | (none — no service bounce) |

Individual services can also be controlled manually with `edp start|stop|status <service>`.

### Compile (git-transport)

`edp <project> compile [host] [-b] [-p:Win64] [-cfg:Release]`  (Delphi)
`edp <project> compile [host] [-skip-tests]`  (Go)

**Projekttyp wird automatisch erkannt** (`_edp_detect_project_type`):
- `.dproj` im Projekt-Root → Delphi-Pfad (MSBuild, siehe unten)
- `go.mod` im Projekt-Root → Go-Pfad (`go build`/`go test`, siehe Abschnitt „Go-Pipeline")
- Weder noch → Fehler

#### Delphi-Pipeline

1. Auto-detect `.dproj` file in project directory (exactly 1 must exist)
2. Git prep (local): refuse if dirty / behind; auto-push if ahead
3. Stop the project's service (if mapped)
4. Git sync on VM:
   - First time: wipe `C:\EDP\<project>\` and `git clone --branch <branch> <origin-url>`
   - Subsequent: `git fetch && git checkout -B <branch> origin/<branch> && git reset --hard origin/<branch>`
   - Untracked build outputs (e.g. `Win64/`, `*.dcu`, `node_modules/`) are kept → incremental rebuilds stay fast
5. SCSS build on VM (only if `package.json` is present in project root):
   - If `node_modules\` doesn't exist yet: `npm install` (once, persists across builds)
   - `npm run scss:build` → compiles all SCSS to `public/css/**/*.min.css`
   - `edpweb` uses this step; projects without `package.json` skip it transparently
6. MSBuild via SSH (direct invocation — **no per-project `compile.cmd`**)
7. SCP the built exe back to the local project directory
8. Start the project's service (if mapped)

The MSBuild command executed on the VM:

```cmd
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" && ^
cd /d C:\EDP\<project> && ^
C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe <Project>.dproj /t:Make /p:config=Release /p:platform=Win64
```

#### Go-Pipeline

Für Projekte mit `go.mod` im Root:

1. Git prep (gleich wie Delphi: clean + auto-push)
2. Service-Stop (über das gleiche Mapping — Libraries ohne Service-Zuordnung überspringen den Schritt)
3. Git-Sync auf VM (`C:\EDP\<project>\`)
4. Falls eine Datei `//go:generate` enthält: `go generate ./...`
5. `go build ./...` — muss fehlerfrei durchlaufen
6. `go test ./...` — läuft standardmäßig, via `-skip-tests` abschaltbar
7. Wenn `main.go` im Repo-Root existiert (= Schnittstelle, nicht reine Library):
   - `go build -ldflags="-s -w" -o <project>.exe .`
   - SCP `<project>.exe` zurück ins lokale Projektverzeichnis
8. Service-Start (falls gemappt)

Reine Library-Projekte (keine `main.go`) überspringen Schritt 7 — kein EXE-Artefakt wird erzeugt oder deployed.

Go-Options:
- `-skip-tests` — `go test` auslassen (z.B. bei Integration-Tests, die echte externe Dienste brauchen)

Voraussetzung auf der VM: Go installiert, `go` im `PATH` der SSH-Session (Standard nach `winget install GoLang.Go`).

### Branch protection

`main` on GHE requires PRs — direct pushes fail. **Always work on a feature branch.** The auto-push in `edp compile` will push the current branch; if you're on `main`, GHE rejects. Use `git checkout -b feature/xyz` before iterating.

### Iterative-dev recipe

```bash
git checkout -b fix/something
git commit -am "wip"          # first try
edp schn_foo compile          # auto-push feature branch + build on VM
# ...fix error...
git commit -a --amend --no-edit
git push --force-with-lease    # or let the helper re-push (it will refuse behind)
edp schn_foo compile
# ...done, open PR, squash-merge
```

### Compile Options

- `-b` — Full Build (default: Make = incremental)
- `-p:Win32` / `-p:Win64` — Override platform (default: `Win64`)
- `-cfg:Debug` / `-cfg:Release` — Override configuration (default: `Release`)

### Log

`edp <project> log [filter] [-l=LEVEL]` — Stream live log with optional text filter and level filter.

### Compilelog

`edp <project> compilelog` — Tail the compile output log on the VM.

## Typical Workflow

```bash
git commit -am "wip"                 # jede Änderung muss committet sein
edp edpweb compile                   # push + VM pullt + Build + fetch exe + Service-Restart
edp start edpwebservice              # Service manuell starten (falls nötig)
edp stop EDPSrv                      # Service manuell stoppen
edp edpweb log                       # Stream live log
```

## Target Directory

Alle Projekte landen in `C:\EDP\<project>` (Projekt-Verzeichnisname = Zielverzeichnis; wird per `git clone` dort angelegt).

## VM Configuration

- **SSH host**: `$EDP_VM_HOST` (gesetzt in `/etc/environment`)
- **Projektpfad**: `$EDP_PROJECT_ROOT` (gesetzt in `/etc/environment`)
- **VM OS**: Windows 11 24H2
- **Delphi**: RAD Studio 13.1 Florence (BDS `37.0`) at `C:\Program Files (x86)\Embarcadero\Studio\37.0\`
- **rsvars.bat**: `C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat`
- **MSBuild**: `C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe` (.NET Framework v4.5)
- **Node.js / npm**: `C:\Program Files\nodejs\` — vorhanden auf VM, wird für SCSS-Build (Dart Sass) genutzt
- **Project root on VM**: `C:\EDP\<project>` (one directory per project; shared libraries like `jvcl`, `jcl`, `DelphiComponents`, `Image32`, `komponenten_delphi`, `HtmlViewer`, `ComPort-Library`, `StyleControls`, `SVGIconImageList`, `SynPDF`, `ELP`, `tzgenerator` also live directly under `C:\EDP\`)

## Adding a New Project

1. Ensure exactly one `.dproj` file exists in the project root (auto-detected by the build system).
2. Project must be a git repo with an `origin` on GHE that the VM can reach (HTTPS credentials per setup above).
3. If the project should be a Windows service, **install the service manually** — the build system never touches service registration, only start/stop.
4. If the project's service is not one of the defaults (`edpwebservice` for `edpweb`, `EDPSrv` for `schn_*`/`server`), add the mapping to `_edp_service_for_project` in `~/.edp_helpers.sh`.
5. First compile will auto-clone into `C:\EDP\<project>\`:
   ```bash
   edp myproject compile
   ```

Abschließend `skill-optimize` mit `edp-develop` aufrufen.

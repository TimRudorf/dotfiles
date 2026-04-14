---
name: edp-develop
description: This skill should be used when the user asks to deploy, compile, or build an EDP project, start/stop/status a Windows service, stream logs, manage the dev VM, or mentions the edp() or devvm() shell functions.
user-invocable: false
---

# EDP Development Tools

Documentation for the `edp()` and `devvm()` shell functions (`~/.edp_helpers.sh`) — central tools for building, deploying, and managing all EDP projects on the Windows dev VM.

## Architecture

- **`compile`** uses **Git as transport** (GHE is source of truth). Local commits are auto-pushed; the VM pulls `origin/<current-branch>` before building.
- **`deploy`** still uses **tar-over-SSH** (legacy path for non-git / production targets that don't pull from GHE).
- Services are managed globally (not per-project).

### Why git-transport for compile

- Every built EXE is bound to a specific commit (reproducibility).
- "What's on the VM right now?" is always a known SHA.
- Works naturally with feature-branch workflow: iterate with WIP commits (use `git commit --amend` between tries), squash-merge at the end.
- No silent drift between local working tree and what was built.

### Compile prerequisites

- Local project directory must be a git repo with an `origin` remote.
- Working tree must be clean (uncommitted changes → `edp compile` refuses).
- Branch must not be behind `origin/<branch>` (divergent history → refuses).
- Branch ahead of remote → auto-pushed.
- VM must be able to authenticate against `origin`. For GHE over HTTPS, configure once per VM:
  ```cmd
  git config --global --unset-all credential.helper
  git config --global --add credential.helper ""
  git config --global --add credential.helper store
  ```
  Then put a line like `https://<user>:<token>@einsatzleitsoftware.ghe.com` into `%USERPROFILE%\.git-credentials` (UTF-8, no BOM — PowerShell's default `Set-Content` writes UTF-16 BOM; use `[IO.File]::WriteAllText(...)` or `Out-File -Encoding utf8NoBOM` instead).

## Usage

```bash
# Project commands
edp <project> deploy [host] [--with-exe]
edp <project> compile [host] [-b] [-p:...] [-cfg:...]
edp <project> log [filter] [-l=LEVEL]
edp <project> compilelog

# Service commands (no project needed)
edp start <service> [host]
edp stop <service> [host]
edp status <service> [host]

# VM lifecycle
devvm start|stop|force-stop|status|console|ip
```

### Services

Windows services are **installed manually** by the user — the build system **never creates services** via `sc create` or similar.

Each project is mapped to the single Windows service that holds its EXE open; that service (and only that service) is stopped before compile/deploy and restarted afterwards. The mapping lives in `_edp_service_for_project` in `~/.edp_helpers.sh`:

| Project name               | Service         |
|----------------------------|-----------------|
| `edpweb`                   | `edpwebservice` |
| `schn_*` (alle Schnittstellen) | `EDPSrv`    |
| `server`                   | `EDPSrv`        |
| everything else            | (none — no service bounce) |

Individual services can also be controlled manually with `edp start|stop|status <service>`.

### Deploy (legacy, tar-based)

For production targets or hosts that don't pull from GHE.

| Mode | Behavior |
|------|----------|
| `edp <project> deploy [host]` | Push files only (no EXE, no DLLs, no service stop). Fast path for JS/HTML/template changes. |
| `edp <project> deploy [host] --with-exe` | Stop all services → push files incl. EXE → start all services |

### Compile (git-transport)

`edp <project> compile [host] [-b] [-p:Win64] [-cfg:Release]`

1. Auto-detect `.dproj` file in project directory (exactly 1 must exist)
2. Git prep (local): refuse if dirty / behind; auto-push if ahead
3. Stop all services
4. Git sync on VM:
   - First time: wipe `C:\EDP\<project>\` and `git clone --branch <branch> <origin-url>`
   - Subsequent: `git fetch && git checkout -B <branch> origin/<branch> && git reset --hard origin/<branch>`
   - Untracked build outputs (e.g. `Win64/`, `*.dcu`) are kept → incremental rebuilds stay fast
5. MSBuild via SSH (direct invocation — **no per-project `compile.cmd`**)
6. SCP the built exe back to the local project directory
7. Start all services

The MSBuild command executed on the VM:

```cmd
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" && ^
cd /d C:\EDP\<project> && ^
C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe <Project>.dproj /t:Make /p:config=Release /p:platform=Win64
```

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

### VM Lifecycle

`devvm start|stop|force-stop|status|console|ip` — Manage the KVM/libvirt development VM (`EifertSystem_Development`).

## Typical Workflow

```bash
edp edpweb deploy                    # Push source files (fast, no service restart)
edp edpweb compile                   # Build + fetch exe (auto-deploys first)
edp edpweb deploy prod-host --with-exe  # Full deploy to production
edp start edpwebservice              # Start a specific service
edp stop EDPSrv                      # Stop a specific service
edp edpweb log                       # Stream live log
```

## Target Directory

All projects deploy to `C:\EDP\<project>` (project directory name = target directory).

## VM Configuration

- **SSH host**: `$EDP_VM_HOST` (gesetzt in `/etc/environment`)
- **Projektpfad**: `$EDP_PROJECT_ROOT` (gesetzt in `/etc/environment`)
- **VM host**: KVM/libvirt, name `EifertSystem_Development`
- **VM OS**: Windows 11 24H2
- **Delphi**: RAD Studio 13.1 Florence (BDS `37.0`) at `C:\Program Files (x86)\Embarcadero\Studio\37.0\`
- **rsvars.bat**: `C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat`
- **MSBuild**: `C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe` (.NET Framework v4.5)
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

---
name: edp-develop
description: This skill should be used when the user asks to deploy, compile, or build an EDP project, start/stop/status a Windows service, stream logs, manage the dev VM, or mentions the edp() or devvm() shell functions.
user-invocable: false
---

# EDP Development Tools

Documentation for the `edp()` and `devvm()` shell functions (`~/.edp_helpers.sh`) — central tools for building, deploying, and managing all EDP projects on the Windows dev VM.

## Architecture

All file transfers use **tar-over-SSH**. Deploy and compile are separate commands. Services are managed globally (not per-project).

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

Two global services: `edpwebservice`, `EDPSrv` (defined in `EDP_SERVICES` array).

During `compile` and `deploy --with-exe`, **both** services are stopped before the operation and started after.

Individual services can be controlled with `edp start|stop|status <service>`.

### Deploy

| Mode | Behavior |
|------|----------|
| `edp <project> deploy [host]` | Push files only (no EXE, no DLLs, no service stop). Fast path for JS/HTML/template changes. |
| `edp <project> deploy [host] --with-exe` | Stop all services → push files incl. EXE → start all services |

### Compile

`edp <project> compile [host] [-b] [-p:Win64] [-cfg:Release]`

1. Auto-detect `.dproj` file in project directory (exactly 1 must exist)
2. Stop all services
3. Deploy files to VM (without EXE)
4. MSBuild via SSH
5. SCP the built exe back to Linux project directory
6. Start all services

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

## Adding a New Project

1. Ensure exactly one `.dproj` file exists in the project root (auto-detected by the build system)
2. If the project runs as a Windows service, register it on the VM:
   ```bash
   ssh "$EDP_VM_HOST" 'sc create MyService binPath= "C:\EDP\myproject\MyApp.exe"'
   ```
3. Deploy and compile:
   ```bash
   edp myproject deploy        # Push source files
   edp myproject compile       # Build + fetch exe
   ```

Abschließend `skill-optimize` mit `edp-develop` aufrufen.

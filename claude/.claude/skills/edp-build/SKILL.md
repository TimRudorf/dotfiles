---
name: edp-build
description: This skill should be used when the user asks to "compile a Delphi project", "build an EDP project", "start/stop a Windows service", "check service status", or mentions the edp() shell function, compile.config, or the dev VM.
user-invocable: false
---

# EDP Build System

Documentation for the `edp()` shell function (`~/.edp_helpers.sh`) — the central build, deploy and service control tool for all EDP projects.

## Architecture

All file transfers use **tar-over-SSH**. Deploy and compile are separate commands:

```bash
edp <project> deploy [host]   # Push files to host, stop/start service
edp <project> compile [host]  # MSBuild on host, fetch exe back
```

Typical workflow:
```bash
edp edpweb deploy eifert-dev      # Source auf Dev-VM schicken
edp edpweb compile                # Bauen + exe zurückholen
edp edpweb deploy dev-edpweb01    # Alles (inkl. exe) auf Remote deployen
```

## Usage

```bash
edp <project> <command> [options]
```

### Commands

| Command | Description |
|---------|-------------|
| `deploy [host]` | Push project files via tar-over-SSH (default host: `$EDP_VM_HOST`) |
| `compile [host] [-b] [-p:Win32\|Win64] [-cfg:Debug\|Release]` | Compile on host + fetch exe (default host: `$EDP_VM_HOST`) |
| `start [host]` | Start Windows service |
| `stop [host]` | Stop Windows service |
| `status [host]` | Query service status |
| `log [filter] [--level=LEVEL]` | Stream live log (levels: fehler, debug, etc.) |
| `compilelog` | Tail the compile output log |

### Compile Options

- `-b` — Full Build (default: Make = incremental)
- `-p:Win32` / `-p:Win64` — Override platform (default from compile.config)
- `-cfg:Debug` / `-cfg:Release` — Override configuration (default from compile.config)

## Deploy Flow

1. Read `TARGET_DIR` from `compile.config` (default: project name)
2. Stop Windows service (if `SERVICE_NAME` set)
3. tar-over-SSH: push all project files to `C:\EDP\<target_dir>` on target host
4. Start Windows service (if `SERVICE_NAME` set)

## Compile Flow

1. Read config from `<project>/compile.config`
2. CLI flags override defaults
3. Stop Windows service (if `SERVICE_NAME` set)
4. SSH to host: `rsvars.bat` → `MSBuild` → compile
5. Check build output for success
6. SCP the built exe back to Linux project directory
7. Start Windows service (if `SERVICE_NAME` set)

## compile.config Format

Each project has a `compile.config` in its repo root:

```ini
PROJECT_NAME=edpweb.dproj
PLATFORM=Win64
CONFIG=Release
SERVICE_NAME=edpwebservice
TARGET_DIR=edpweb
```

| Key | Description |
|-----|-------------|
| `PROJECT_NAME` | Delphi `.dproj` filename |
| `PLATFORM` | `Win32` or `Win64` |
| `CONFIG` | `Release` or `Debug` |
| `SERVICE_NAME` | Windows service name (optional — omit if no service) |
| `TARGET_DIR` | Subdirectory under `C:\EDP\` (optional, defaults to project name) |

## Target Directory

All projects deploy to `C:\EDP\<TARGET_DIR>`. The `TARGET_DIR` defaults to the project name if not set in `compile.config`.

## VM Configuration

- **SSH alias**: `eifert-dev` (configured in `~/.ssh/config`)
- **Default host**: `$EDP_VM_HOST` (eifert-dev)
- **VM host**: KVM/libvirt, name `EifertSystem_Development`
- **VM lifecycle**: `devvm start|stop|force-stop|status|console|ip`

## Adding a New Project

1. Create `compile.config` in the project directory
2. If the project runs as a Windows service, register it on the VM:
   ```bash
   ssh eifert-dev 'sc create MyService binPath= "C:\EDP\myproject\MyApp.exe"'
   ```
3. Deploy and compile:
   ```bash
   edp myproject deploy        # Push source files
   edp myproject compile       # Build + fetch exe
   ```

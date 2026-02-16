# EDP Build System

Documentation for the `edp()` shell function (`~/.edp_helpers.sh`) — the central build, deploy and service control tool for all EDP projects.

## Usage

```bash
edp <project> <command> [options]
```

### Commands

| Command | Description |
|---------|-------------|
| `compile [-b] [-p:Win32\|Win64] [-cfg:Debug\|Release]` | Compile (default: incremental Make) |
| `start` | Start Windows service |
| `stop` | Stop Windows service |
| `status` | Query service status |
| `log [filter] [--level=LEVEL]` | Stream live log (levels: fehler, debug, etc.) |
| `compilelog` | Tail the compile output log |

### Compile Options

- `-b` — Full Build (default: Make = incremental)
- `-p:Win32` / `-p:Win64` — Override platform (default from compile.config)
- `-cfg:Debug` / `-cfg:Release` — Override configuration (default from compile.config)

## Compile Flow

1. Read defaults from `<project>/compile.config`
2. CLI flags override defaults
3. Stop Windows service (if `DEPLOY_MODE` ≠ `none` and `SERVICE_NAME` set)
4. SSH to VM: `rsvars.bat` → `MSBuild` → compile
5. Deploy based on `DEPLOY_MODE`:
   - `mirror`: `robocopy /mir` to `C:\<project>\`
   - `exe`: copy EXE to `C:\edpserver\`
   - `none`: skip deploy
6. Start Windows service (same condition as step 3)

## compile.config Format

Each project has a `compile.config` in its repo root:

```ini
PROJECT_NAME=edpweb.dproj
PLATFORM=Win64
CONFIG=Release
SERVICE_NAME=edpwebservice
DEPLOY_MODE=mirror
```

| Key | Description |
|-----|-------------|
| `PROJECT_NAME` | Delphi `.dproj` filename |
| `PLATFORM` | `Win32` or `Win64` |
| `CONFIG` | `Release` or `Debug` |
| `SERVICE_NAME` | Windows service name (optional — omit if no service) |
| `DEPLOY_MODE` | `none` (default), `mirror` (robocopy), `exe` (copy EXE only) |

## VM Configuration

- **SSH alias**: `eifert-dev` (configured in `~/.ssh/config`)
- **SMB share**: `\\192.168.122.1\edp` → mounts to `C:\Users\Admin\Entwicklung\` on VM
- **VM host**: KVM/libvirt, name `EifertSystem_Development`
- **VM lifecycle**: `devvm start|stop|force-stop|status|console|ip`

## Service Paths on VM

| Project | Service | Binary Path | Deploy Mode |
|---------|---------|-------------|-------------|
| edpweb | `edpwebservice` | `C:\edpweb\edpweb.exe` | `mirror` |
| schn_ivena | `EDPSrv` | `C:\edpserver\Schn_IVENA.exe` | `exe` |

## Adding a New Project

1. Create `compile.config` in the project directory (set `DEPLOY_MODE` accordingly)
2. If the project runs as a Windows service, register it on the VM:
   ```bash
   ssh eifert-dev 'sc create MyService binPath= "C:\edpserver\MyApp.exe"'
   ```

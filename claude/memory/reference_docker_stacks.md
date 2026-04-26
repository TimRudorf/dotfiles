---
name: Docker Compose Stacks Standort
description: Wo Tims Docker-Compose-Files liegen (Proxmox -> Debian-VM) und das zugehörige Git-Repo
type: reference
originSessionId: cbd92e98-dddc-4e6e-99bd-eabdf2cb30ad
---
Docker-Compose-Stacks liegen in `/opt/stacks` auf einer Debian-VM, die auf Tims Proxmox-Server läuft.

**Zugriffskette:**
- Proxmox-Host: hostname `proxmox`, user `timrudorf`
- Debian-VM darauf: `172.16.0.3`, user `timrudorf`
- Stacks-Verzeichnis in der VM: `/opt/stacks`

**Git-Repo (Quelle der Wahrheit für die Compose-Files):**
- `git@github.com:TimRudorf/docker-compose.git`

**How to apply:** Wenn der User nach Docker-Stacks, Compose-Files oder laufenden Containern fragt: Für das *Bearbeiten* der Compose-Files bevorzugt das Git-Repo klonen/ziehen. Für Laufzeit-Inspektion (Container-Status, Logs, tatsächlich deployte Version) per SSH auf die Debian-VM (`172.16.0.3`) -> `/opt/stacks`. Die Proxmox-Maschine selbst hostet nur die VM, nicht die Stacks direkt.

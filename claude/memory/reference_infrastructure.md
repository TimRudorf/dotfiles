---
name: Tims Infrastruktur-Übersicht
description: Wo Tims Server / Geräte stehen, was 24/7 läuft, was Compute-mäßig und Netzwerk-mäßig wo verfügbar ist
type: reference
originSessionId: 6da8ffce-ed73-4d31-92fe-c648997a3234
---
**Drei Standorte / Compute-Knoten:**

## 1. Frankfurt (Tims Wohnung) — Always-On
- **Raspberry Pi**, läuft **24/7**
- Darauf: **Home Assistant** (Smart-Home-Steuerung)
- **Einziger 24/7-Server bei Tim selbst zuhause** — alles andere kann offline sein
- Netzwerk: hinter **UniFi Dream Machine (alt)** Router

## 2. Glashütten (Elternhaus) — Hauptserver
- **Proxmox-Host** (Bare-Metal), nennt sich `proxmox`, user `root`
- Darauf läuft (mind.) eine **Debian-VM** auf `172.16.0.3`, user `timrudorf`
  - Auf der VM: **Docker** mit allen Compose-Stacks unter `/opt/stacks` (siehe `reference_docker_stacks.md`)
  - Git-Repo der Compose-Files: `git@github.com:TimRudorf/docker-compose.git`
  - Hier läuft auch **`jarvis-workspace`-Container** (das hier — wo Claude wohnt)
- Netzwerk: hinter **UniFi Dream Machine Pro** (Rack-Variante, der gute Router)

## 3. VPS (Hetzner/o.ä., Cloud)
- Erreichbar per **SSH-Key** (kein Passwort) — User-Setup vorhanden
- Darauf: **Docker** mit **SWAG** (`linuxserver/swag` als Reverse-Proxy)
- **Tailscale** verbindet VPS ↔ Glashütten-Server
- **Funktion:** SWAG terminiert TLS und reverse-proxyt ausgewählte Docker-Container vom Glashütten-Server **nach außen** ins öffentliche Internet
- Konkrete Zugangsdaten in `reference_vps_access.md` (öffentliche IP `82.165.47.37`, root-SSH per Key)

**Tailnet:** Tim betreibt Tailscale (`taile8466e.ts.net`). Auch der `jarvis-workspace`-Container hängt seit 2026-04-27 dran (Network-Namespace-Sharing mit Sidecar). Konkrete Hosts/IPs in `reference_tailscale.md`.

## Datenfluss-Schema (Standardweg "Service nach außen verfügbar machen"):
```
Internet
   │
   ▼
VPS (öffentl. IP, SWAG)  ── Tailscale ──►  Glashütten Debian-VM (172.16.0.3, Docker-Stack)
                                                   │
                                                   ▼
                                              Compose-Service (z.B. Nextcloud, Jarvis-Bridge, …)
```

## How to apply
- Bei Frage "wo läuft X": Default-Annahme = Glashütten-Debian-VM, Docker-Compose. Home Assistant = Pi in Frankfurt.
- Bei "öffentlich erreichbar machen": Reverse-Proxy via SWAG auf VPS hinzufügen, Tailscale-Routing prüfen — nicht direkt Port forwarding bei Tim zuhause.
- Bei "muss 24/7 laufen ohne Eltern-Server-Abhängigkeit": Pi in Frankfurt nutzen (begrenzte Ressourcen — nur Lightweight-Sachen).
- Wenn ein neuer Service angedacht wird: erst überlegen wo er hin soll (Pi vs. VM vs. VPS) — Default = Glashütten-VM für alles was Compute braucht.
- Beide Standorte (Frankfurt + Glashütten) haben **UniFi-Hardware** → Tim hat Erfahrung damit, kann VLANs/Firewall-Regeln dort managen.

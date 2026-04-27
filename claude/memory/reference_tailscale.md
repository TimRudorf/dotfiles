---
name: Tims Tailnet (Tailscale)
description: Tailnet-Domain, bekannte Hosts mit Tailscale-IPs, und wie der jarvis-workspace-Container daran hängt
type: reference
originSessionId: e665452d-f361-4fda-bca6-80320f059636
---
**Tailnet-Domain:** `taile8466e.ts.net` (MagicDNS aktiv)

## Container-Anbindung (jarvis-workspace)
- Kein eigener `tailscale`-CLI im Container; stattdessen **Network-Namespace-Sharing** mit einem benachbarten Tailscale-Sidecar.
- Erkennbar an `/etc/resolv.conf`: `nameserver 100.100.100.100` + `search taile8466e.ts.net`.
- Heißt: alle Tailscale-Peers per **Hostname** auflösbar, kein Subnet-Router-Setup nötig — Verbindung läuft "wie vom Sidecar aus".
- `ping` ist **nicht** installiert; für Reachability-Checks `bash -c 'cat </dev/tcp/<host>/<port>'` oder `curl -m 5` nutzen.

## Bekannte Hosts (Stand 2026-04-27, verifiziert)
| Hostname | Tailscale-IP | Was läuft | Standort |
|---|---|---|---|
| `hermes` | 100.125.222.128 | **VPS** (öffentl. IP 82.165.47.37, SSH als root) mit SWAG-Reverse-Proxy als einzigem Stack | Cloud |
| `proxmox` | 100.97.134.101 | Proxmox-Host (SSH :22, Web-UI :8006) | Glashütten |
| `debian` | (LAN 172.16.0.3, via proxmox-Subnet-Route) | Debian-VM mit Docker-Stacks (Hauptserver) | Glashütten |
| `homeassistant` | 100.126.123.45 | Home Assistant (:8123) auf dem Pi | Frankfurt |
| `jarvis-workspace` | 100.103.171.39 | **dieser Container** (Network-Namespace-Share mit Sidecar) | Glashütten (in Debian-VM) |
| `macbook` | 100.121.30.101 | Tims MacBook | mobil |
| `iphone` | 100.111.67.116 | Tims iPhone | mobil |
| `ipad` | 10.0.10.51 | Tims iPad (LAN-IP, vermutlich nur im Heimnetz aktiv) | mobil/zuhause |
| `hades` | 100.113.243.113 | Windows-Host, oft offline | — |
| `poseidon` | 100.81.95.35 | Linux-Host, oft offline | — |

## How to apply
- Wenn ich auf Glashütten-VM zugreifen soll: per `debian` (172.16.0.3) ansprechen — geht über Tailscale-Routing, Hostname stabiler als IP.
- Wenn ich Proxmox-Konfig brauche: `ssh timrudorf@proxmox` bzw. `https://proxmox:8006`.
- Wenn ich Smart-Home-Daten will: `http://homeassistant:8123`.
- Bei Connectivity-Tests immer `curl -m 5` oder `/dev/tcp` statt `ping` (fehlt im Container).
- Hostnamen bevorzugt vor IPs verwenden — MagicDNS macht's hostübergreifend (Mac und Container) gleich nutzbar.

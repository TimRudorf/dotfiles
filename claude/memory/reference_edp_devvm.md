---
name: EDP Dev-VM Netzwerk
description: vm-eifert-develop hat fixe LAN-IP 172.16.0.2 (Proxmox 172.16.0.3), keine eigene Tailscale-IP — von außen nur über Subnet-Router (proxmox-Peer)
type: reference
originSessionId: 1f1df471-5c54-4417-a2a2-a1e7705f21e0
---
**Dev-VM `vm-eifert-develop`:**
- LAN-IP: **172.16.0.2** (fix)
- Hat **keine eigene Tailscale-Installation**
- Erreichbar über Tailscale **nur via Subnet-Router** (proxmox-Peer, IP 100.97.134.101, advertised `172.16.0.0/28`)

**Praktische Folgen:**
- Vom VPS (oder anderen Tailscale-Peers) aus: direkt `172.16.0.2` ansprechen — keine 100.x-IP für die Dev-VM.
- SWAG `edpweb.subdomain.conf` muss `set $upstream_app 172.16.0.2;` haben (nicht eine 100.x-IP).
- Wenn Routes nicht funktionieren: prüfen ob proxmox-Peer die `/28`-Route advertised und der Ziel-Host `--accept-routes` aktiv hat (`tailscale set --accept-routes`), plus die Route im Tailscale-Admin-Panel approved ist.

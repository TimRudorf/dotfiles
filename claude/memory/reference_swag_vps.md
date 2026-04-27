---
name: SWAG Reverse Proxy auf VPS
description: SWAG (linuxserver Reverse Proxy) läuft nur direkt auf dem VPS, ist NICHT im docker-compose Repo (TimRudorf/docker-compose) versioniert
type: reference
originSessionId: 1f1df471-5c54-4417-a2a2-a1e7705f21e0
---
SWAG (Secure Web Application Gateway, linuxserver/swag) ist der Reverse-Proxy für *.timrudorf.de und liegt **ausschließlich auf dem VPS** — also nicht im Repo `~/dev/docker-compose/` und nicht in den Stacks unter `/opt/stacks/` auf der Heim-VM 172.16.0.3.

**Wo gucken:** Direkt auf den VPS per SSH einloggen. Configs typischerweise unter dem SWAG-Datenverzeichnis (`nginx/proxy-confs/*.subdomain.conf`).

**Praktische Folgen:**
- Für neue Subdomains (z.B. `edpweb.timrudorf.de`) muss eine `.subdomain.conf` direkt auf dem VPS in das SWAG-`proxy-confs`-Verzeichnis abgelegt und SWAG reloadet werden.
- Änderungen sind nicht im Git, also ggf. zusätzlich an Tim zur Doku/Backup melden oder in eine separate Notiz packen.
- Heim-VM und VPS sind getrennte Hosts — der VPS proxyt von außen rein, die Heim-VM (Dev-VM, EDP) erreicht er nur, wenn ein Tunnel/VPN/Routing dazwischen aktiv ist.

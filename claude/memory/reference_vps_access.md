---
name: VPS Zugang
description: SSH-Zugang zum VPS (timrudorf.de Reverse-Proxy / SWAG-Host) via root@82.165.47.37 mit SSH-Key
type: reference
originSessionId: 1f1df471-5c54-4417-a2a2-a1e7705f21e0
---
**VPS:** `82.165.47.37`
**Login:** `ssh root@82.165.47.37` (SSH-Key liegt lokal, kein Passwort nötig)

**Was läuft dort:**
- SWAG Reverse-Proxy für `*.timrudorf.de` (siehe reference_swag_vps.md)
- Vermutlich weitere öffentlich erreichbare Services (Nextcloud cloud.timrudorf.de etc.)

**How to apply:** Wenn Tim Subdomains/Reverse-Proxy-Configs unter `*.timrudorf.de` erreichbar machen will, hier per SSH rein, SWAG-`proxy-confs` anpassen, SWAG reloaden. Änderungen sind nicht in Git — Tim ggf. an Backup/Doku-Bedarf erinnern.

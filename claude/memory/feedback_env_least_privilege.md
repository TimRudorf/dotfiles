---
name: .env nach Least-Privilege filtern, nicht 1:1 kopieren
description: Bei neuen Compose-Stacks nur die tatsächlich benötigten Env-Vars rüberziehen, nicht das ganze sops-.env
type: feedback
originSessionId: 6da8ffce-ed73-4d31-92fe-c648997a3234
---
Wenn ein neuer Stack ein eigenes `.env` braucht und die Werte aus dem zentralen sops-Bestand kommen: **NIEMALS** stumpf `cp /opt/stacks/jarvis/.env /opt/stacks/<neuer-stack>/.env`. Stattdessen mit `grep -E "^(VAR_A|VAR_B|...)="` filtern und nur die echt benötigten Variablen rüberziehen.

**Why:** Tim hat das beim data-api-Stack 2026-04-27 explizit korrigiert. Argument: jeder Container, der ein .env mit allen sops-Werten bekommt, sieht im Kompromittierungsfall alle Tokens (Zammad, GitHub, Nextcloud, OpenAI, …). Blast-Radius minimieren ist wichtiger als der Bequemlichkeitsgewinn vom Vollkopieren.

**How to apply:**
- Bei jedem neuen Compose-Stack mit `.env`: vorher überlegen, welche Vars der Stack wirklich liest (Compose-File durchschauen).
- Schreibmuster:
  ```bash
  TMP=$(mktemp /opt/stacks/<stack>/.env.XXXXXX); chmod 600 "$TMP"
  grep -E "^(VAR_A|VAR_B|VAR_C)=" /opt/stacks/jarvis/.env > "$TMP"
  mv "$TMP" /opt/stacks/<stack>/.env
  chmod 600 /opt/stacks/<stack>/.env
  ```
- `chmod 600` ist Pflicht. atomar via tmp+mv damit der Service nie ein halbgeschriebenes File sieht.
- Bei Key-Rotation: gleiches Filterskript nochmal durchziehen, danach `docker compose up -d --force-recreate`.
- Wenn ein Stack viele zentrale Werte braucht (z.B. ein Reporting-Tool, das mehrere APIs anspricht): trotzdem explizit listen, nicht kopieren — auch als Doku, was tatsächlich gebraucht wird.

## Spezialfall: `TS_AUTHKEY` (Tailscale-Sidecar)

`TS_AUTHKEY` wird von `tailscale/tailscale`-Sidecars **nur beim allerersten Start** gebraucht (Initial-Authentication). Danach liegt der Tailscale-State persistent im Volume (`/var/lib/tailscale`), Restart liest ihn ohne erneuten Key. Heißt: **nach dem ersten erfolgreichen Boot `TS_AUTHKEY` aus dem `.env` entfernen** — er liegt sonst unnötig rum und wäre bei Container-Kompromittierung ein Werkzeug, um beliebige neue Tailnet-Knoten anzulegen.

Proof: Logs zeigen nach Re-Create ohne Key `machineAuthorized=true; authURL=false` — Auth aus State, nicht aus Env.

Wenn das State-Volume verloren geht (z.B. `docker compose down -v` oder Volume-Wipe): Key temporär wieder einfügen, Container starten, danach wieder entfernen.

Gilt für alle Tailscale-Sidecars (data-api, jarvis, künftige Stacks).

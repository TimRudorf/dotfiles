---
name: Jarvis Repo lokal
description: Lokaler Klon von TimRudorf/docker-compose mit Jarvis-Bridge-Code für Lese-/Such-Zugriff ohne SSH
type: reference
originSessionId: ca1a20ce-807c-48db-9b55-2d95e93c7514
---
Lokaler Klon: `~/dev/docker-compose/` (GitHub: `TimRudorf/docker-compose`)

Jarvis-relevante Pfade:
- Bridge-Code: `~/dev/docker-compose/jarvis/bridge/src/` (TS, grammy, läuft im `jarvis-bridge`-Container)
- Workspace-Container-Setup: `~/dev/docker-compose/jarvis/workspace/` (Dockerfile + entrypoint.sh)
- Compose: `~/dev/docker-compose/jarvis/compose.yaml`

Auf der VM 172.16.0.3 läuft das Live-Repo unter `/opt/stacks/` (siehe `reference_docker_stacks.md`). Lokaler Klon ist read-only-Referenz für Code-Suche; Änderungen entweder direkt auf VM oder PR via GitHub.

Beim Pullen: `git -C ~/dev/docker-compose pull` — Branch ist `main`.

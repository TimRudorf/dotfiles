---
name: Jarvis-Deploy — Git-Source-of-Truth + Feature-Branch + Test-First
description: Code-Änderungen an Jarvis/Stack-Code immer über Git (kein scp), und nicht-trivial immer über Feature-Branch — Tim testet, Merge erst nach OK
type: feedback
originSessionId: ca1a20ce-807c-48db-9b55-2d95e93c7514
---
Konsolidierter Workflow für jede Code-Änderung am Jarvis-Stack (Bridge, Workspace-Dockerfile, Compose, alles unter `/opt/stacks/*`) oder anderen Tim-Repos.

## Regel 1: Git ist Source of Truth — kein scp

1. Lokal in `~/dev/docker-compose/` editieren.
2. Commit + push auf GitHub (`TimRudorf/docker-compose`).
3. Auf VM: `cd /opt/stacks && git pull` und dann `docker compose build … && docker compose up -d …`.

**Why:** scp umgeht Git, hinterlässt Drift zwischen lokalem Klon, GitHub und VM. History fehlt, Rollback nervig, im PR-/Commit-Verlauf ist nicht sichtbar was passiert ist.

## Regel 2: Nicht-trivial → Feature-Branch + Test-First

Für nicht-triviale Änderungen (Bug-Fix mit Auswirkung, Feature, Refactor):

1. Feature-Branch lokal anlegen: `git checkout -b feat/xyz` oder `fix/xyz`.
2. Commit + Push auf den Branch (NICHT main): `git push -u origin feat/xyz`.
3. VM auf den Branch wechseln: `cd /opt/stacks && git fetch && git checkout feat/xyz && git pull`.
4. Build + Restart der betroffenen Services.
5. **Tim testet** im Telegram-Chat o.ä.
6. **Merge erst nach OK** vom User: `gh pr merge` oder `git merge` auf main, dann VM zurück auf main.

**Why:** Tim will die Änderung in der echten Umgebung sehen, bevor sie auf main wandert. Direkt-auf-main-pushen umgeht den Test-Schritt — wenn was kaputt ist, ist Rollback schmerzhafter als ein Branch-Discard.

## Wann direkt auf main OK ist

- Triviale Doku-/Memory-/Kommentar-Änderungen außerhalb des Code.
- Tim sagt explizit *"direkt auf main"*.
- Kleinkram, der nichts deployt (Readme, Comment-Fix, etc.).

**How to apply:** Standardmäßig Branch-Workflow. Nur weichen wenn klar trivial ODER Tim ausdrücklich abkürzen will. Tim merged solo auf main → Push auf main ohne PR-Review ist OK (small-team-Workflow), aber bei Code-Änderungen am Stack lieber Branch + PR anbieten und auf Test-OK warten.

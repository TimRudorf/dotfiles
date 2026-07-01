---
name: container-update
description: Kontrollierter, gestaffelter Update-Durchlauf für Tims Docker-Container-Flotte auf der Debian-VM (jarvis-vm, Stacks im Repo TimRudorf/docker-compose, Mac-Klon ~/dev/docker-compose). Nutzen, wenn Tim Container oder Images aktualisieren will — Trigger: "update mal alle container", "container updaten", "bring die container auf latest", "/container-update". Läuft Inventory → Proxmox-Snapshot → Abhängigkeits-Recherche → gestaffeltes Ausrollen (Low-Risk zuerst, Nextcloud zuletzt) → Verify pro Dienst → Git-Roundtrip + Vault-Update. Pinnt jedes Image digest-genau (repo:version@sha256). Domain-Gotchas stehen in der Vault-Note referenz/nextcloud-container.
---

# Container-Update (Fleet-Update)

Aktualisiert Tims selbstgehostete Docker-Flotte auf der Debian-VM sicher und gestaffelt. Jede Image-Referenz wird digest-genau gepinnt (`repo:version@sha256:<digest>`). Reihenfolge nach Risiko, Verify nach jedem Stack, Rollback-Netz per Proxmox-Snapshot.

**Grundprinzip:** Neustart/Deploy darf nie überraschen. Erst recherchieren, dann Snapshot, dann gestaffelt ändern, nach jedem Schritt verifizieren. Kein "fertig" ohne Verify.

## Voraussetzungen
- Tools: `ssh`, `scp`, `git`, `gh`
- Datei: `~/.ssh/id_ed25519`
- Projekt: `~/dev/docker-compose`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Fixpunkte (Infrastruktur)
- **VM:** `ssh jarvis-vm` (Debian, 172.16.0.3), Stacks unter `/opt/stacks/<stack>/compose.yaml`
- **Proxmox-Host:** `ssh -i ~/.ssh/id_ed25519 root@100.97.134.101`, die VM ist **VM 103** (debian)
- **Mac-Klon:** `~/dev/docker-compose` (Repo `TimRudorf/docker-compose`)
- **Vault-Note (Gotchas + deployte Versionen):** `$VAULT/referenz/nextcloud-container.md` — VOR Beginn lesen, am Ende updaten
- **NIE anfassen:** `tailscale:stable` (Security-Layer, soll tracken), Eigen-Builds (`jarvis-workspace`, `jarvis-bridge`, `data-api-server` — Git/CI-versioniert), `dockge` (nicht im Repo)

## Phase 0 — Inventory & Snapshot (Pflicht-Gate)

1. **Vault-Note lesen** (`referenz/nextcloud-container`) für Gotchas, kritische Stacks, letzte Versionen.
2. **Vollständiges Inventory** aller laufenden Container mit Image-Ref + echter Version. Pro Container eine Abhak-Liste anlegen (TaskCreate bei ≥3 offenen) — **kein Container darf durchrutschen** (im letzten Lauf wurden homepage+vaultwarden zunächst übersehen). Version-Label holen:
   ```bash
   ssh jarvis-vm 'for c in $(docker ps --format "{{.Names}}"|sort); do printf "%-18s %s\n" "$c" "$(docker inspect --format "{{.Config.Image}}" "$c")"; done'
   ```
3. **Proxmox-Snapshot als HARTES Gate** — ohne Snapshot nicht weitermachen:
   ```bash
   ssh -i ~/.ssh/id_ed25519 root@100.97.134.101 'qm snapshot 103 preupdate-<YYYYMMDD-HHMM> --description "Vor Container-Fleet-Update"'
   ```
   (`<YYYYMMDD-HHMM>` per `date` erzeugen.) Erfolg mit `qm listsnapshot 103` prüfen.

## Phase 1 — Abhängigkeits-Recherche (vor dem Anfassen)

Für **kritische/stateful Stacks** (Nextcloud, Paperless, OnlyOffice, Datenbanken) ist Web-Recherche der Kompatibilitäts-Matrizen **verpflichtend, bevor** irgendetwas geändert wird. Parallel recherchieren lassen. Pro Stack als Ergebnis gebraucht:

```json
{ "service": "nextcloud", "current": "33.0.2", "target_stable": "34.0.1",
  "staged_path": ["33.0.6", "34.0.1"], "deps": {"mariadb": "11.8 supported+recommended", "redis": "unchanged"},
  "gotchas": ["ein Major/Schritt", "connector-app >=10.1.0 fuer NC34"], "sources": ["<url>"] }
```

Zu klären: NC-Major-Upgrade-Pfad (ein Major/Schritt) + supported MariaDB/Redis/PHP; OnlyOffice DocumentServer ↔ NC-Connector-App-Kompatibilität inkl. **bekannter Bugs** (nicht blind `latest` — z.B. hatte DS 9.4.x einen Blank-Document-Bug); Paperless-ngx neueste **stabile** (kein `x.0.0-beta`) + Redis-Version + paperless-gpt-Kompat. Low-Risk-Stacks (arr/media/homepage/vaultwarden) brauchen keine Recherche.

## Phase 2 — Gestaffelt ausrollen

Reihenfolge nach Risiko: **erst Low-Risk unabhängige Stacks** (arr, media, homepage, vaultwarden), **dann Paperless**, **zuletzt Nextcloud**. Pro Stack:

1. **Ziel-Image ziehen** und Digest + Version holen (Digest steht am **Image**, nicht am Container):
   ```bash
   ssh jarvis-vm 'docker pull -q <repo>:<zieltag> >/dev/null && \
     docker image inspect --format "{{index .Config.Labels \"org.opencontainers.image.version\"}} {{index .RepoDigests 0}}" <repo>:<zieltag>'
   ```
2. **Compose-Zeile pinnen** im Mac-Klon (`Edit`): `image: <repo>:<version>@sha256:<digest>`.
3. **Auf VM übertragen + deployen:**
   ```bash
   scp -q ~/dev/docker-compose/<stack>/compose.yaml jarvis-vm:/opt/stacks/<stack>/compose.yaml
   ssh jarvis-vm 'cd /opt/stacks/<stack> && docker compose up -d'
   ```
4. **Sofort verifizieren** (Phase 3), erst dann nächster Stack.

**Nextcloud-Stack (Sonderfall, zuletzt):**
- Nextcloud-Major **gestuft**, ein Major pro Schritt (z.B. 33.0.2 → neuestes 33er-Patch → 34.0.x). linuxserver taggt den **Vor-Major** mit `-previous`-Suffix (z.B. `33.0.6-previous`), kein plain `33.0.6`.
- Das linuxserver-Image fährt `occ upgrade` beim Boot **selbst**; niemals manuell. Es verweigert den Boot bei >1 Major Rückstand.
- **MariaDB/Redis beim NC-Major bewusst stabil lassen** (weniger Variablen). Nur `docker compose up -d nextcloud` (bzw. `onlyoffice`) statt ganzem Stack, damit DB nicht unnötig neu startet.
- OnlyOffice: DocumentServer-Ziel per Recherche (nicht blind latest); Volume-Mapping + `JWT_SECRET` bleiben identisch. Connector-App zieht das NC-Major-Upgrade meist automatisch aus dem App Store nach.

## Phase 3 — Verify pro Dienst (nach JEDEM Stack)

Kein Stack gilt als fertig, bevor er grün ist. Restart-Loops immer prüfen: `docker ps -a | grep -iE "restarting|exited|unhealthy"`.

- **Web-Dienste:** HTTP-Code je Service-Port (200/302/401 = lebt). Ports stehen in `docker ps --format '{{.Names}} {{.Ports}}'`.
- **Nextcloud:** `docker exec -u abc nextcloud php /app/www/public/occ status` → `versionstring` korrekt, `maintenance: false`, `needsDbUpgrade: false`; extern `https://cloud.timrudorf.de/status.php` = 200; `occ onlyoffice:documentserver --check` muss **"successfully connected"** sagen; danach `occ app:update --all`. (occ-status mid-upgrade kann `maintenance:true` zeigen — Log auf "Update successful" prüfen, dann erneut.)
- **Paperless:** Log `docker logs paperless-ngx` → "No migrations to apply" bzw. saubere Migration; `docker exec paperless-broker redis-cli ping` = PONG.
- **DB/Redis:** dass NC/Paperless nach dem Neustart wieder verbinden (occ status / ping) ist der Beweis.

## Phase 4 — Abschluss

1. **Git-Roundtrip** (Mac-Klon, Repo ist privat → autonom, kein Approval):
   ```bash
   cd ~/dev/docker-compose && git checkout -b update-all-<datum> && git add -A && \
     git commit -m "update: <versions-summary>" && git push -u origin update-all-<datum> && \
     gh pr create --fill && gh pr merge --squash --delete-branch && git checkout main && git pull --ff-only
   ```
   Commit-Body: pro Stack `alt->neu` + Snapshot-Name + Kern-Entscheidungen (z.B. warum nicht latest).
2. **VM reconcilen** (die per scp gesetzten Dateien mit git in Deckung bringen):
   ```bash
   ssh jarvis-vm 'cd /opt/stacks && git checkout -- . && git pull --ff-only'
   ```
   `git status --short` muss leer sein (VM-Compose == git == laufende Container).
3. **Vault-Note updaten** (`referenz/nextcloud-container`): deployte Versionen + neu entdeckte Gotchas. Keine Inhalte duplizieren, nur die Faktenschicht pflegen.
4. **Snapshot** dem User melden (nach ein paar Tagen stabilem Betrieb löschbar: `qm delsnapshot 103 <name>`). Bei Problemen ist Rollback per Snapshot oder alten Digest sofort möglich.

Abschließend `skill-optimize` mit `container-update` aufrufen.

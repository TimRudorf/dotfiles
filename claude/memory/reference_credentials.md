---
name: Credentials / .env Standorte + Token-Details
description: Wo Jarvis die Zugangsdaten findet; Schema-Konvention PRIVATE/WORK; Routing via CONTEXTS.md; Detail-Hinweise zu GitHub-Tokens und Nextcloud-Endpoints
type: reference
originSessionId: cbd92e98-dddc-4e6e-99bd-eabdf2cb30ad
---
**Single Source of Truth:** `~/dotfiles/secrets/env.sops` — sops-verschlüsselt mit age, im Public-Repo `TimRudorf/dotfiles` committet. Drei Recipients: Mac-Key (`~/.config/sops/age/keys.txt`), VM-Key (auf 172.16.0.3, dito), Backup-Key (Vaultwarden-Eintrag "SOPS age backup key (dotfiles)").

**Decrypt-Workflow:**
- Mac: `~/dotfiles/scripts/decrypt-env.sh` → schreibt `~/.env` (mode 0600), wird von `.zshrc` ge-`source`-d.
- VM: `~/dotfiles/scripts/decrypt-env.sh --restart-jarvis` → schreibt `/opt/stacks/jarvis/.env` und `docker compose up -d jarvis-workspace`.

**Editieren:** `sops ~/dotfiles/secrets/env.sops` → öffnet $EDITOR mit Klartext, beim Speichern wieder verschlüsselt. Danach commit + push, beide Hosts pullen + decrypten. Niemals `~/.env` oder `/opt/stacks/jarvis/.env` direkt editieren — wird beim nächsten decrypt überschrieben.

**Host-spezifische Werte** (z.B. Pfade) gehören NICHT in die sops-Datei. Mac-Overrides: `~/dotfiles/shell/.zshrc.darwin`. Aktuell dort: `EDP_PROJECT_ROOT="$HOME/dev/EDP"` (auf VM ist es `/workspace/EDP`).

**SOPS_AGE_KEY_FILE** muss auf macOS explizit gesetzt sein (Default-Pfad ist dort `~/Library/Application Support/sops/age/keys.txt`, nicht `~/.config/...`). In `~/dotfiles/shell/.zshrc` exportiert.

## Konvention

- **Single-Service-Keys** ohne Suffix: `ZAMMAD_HOST`, `ZAMMAD_TOKEN`, `OPENAI_API_KEY`, `MEALIE_*`, `REMARKABLE_*`, `ABS_*`, `RADARR_*`, `SONARR_*`, `PLEX_*`, `DOKUWIKI_*`, `PEXELS_TOKEN`, `PUSHOVER_USER_KEY`, `EDP_*`, `RM_*`
- **Dual-Service-Keys** mit Suffix `_PRIVATE` / `_WORK`:
  - Nextcloud: `NC_PRIVATE_{HOST,USER,PASSWORD,WEBDAV}` + `NC_WORK_{HOST,USER,PASSWORD,WEBDAV}`
  - GitHub: `GH_PRIVATE_TOKEN` (github.com) + `GH_WORK_HOST`, `GH_WORK_TOKEN` (EDP Enterprise)

## Nutzung allgemein

- Wenn du in einer Task ein Secret brauchst: die Env-Var lesen (`$KEY_NAME`), nicht irgendwo anders suchen. Die Vars sind via Shell/Compose schon verfügbar.
- Bei Dual-Services **nicht raten**, welches zu nehmen ist — siehe `~/.claude/CONTEXTS.md` für die Kontext-Heuristik (Work-/Private-Signale im Prompt, Rückfrage bei Ambiguität).
- Fehlt dir ein Key (Var nicht gesetzt): sag Tim *"dafür bräuchte ich `XYZ` in der `.env`, bitte ergänzen"*, nicht Umweg bauen.
- Template + Erklärung pro Key steht in `docker-compose/jarvis/.env.example`.
- Backups der vorherigen `.env`-Versionen liegen mit Timestamp-Suffix neben der aktiven Datei (`.env.bak-YYYYMMDD-HHMMSS`) — auf beiden Systemen.

## GitHub-Tokens — wann welcher

Tokens sind nicht austauschbar — `GH_WORK_TOKEN` funktioniert nicht gegen github.com und umgekehrt. Vor dem ersten Schreibzugriff einmal den Host checken statt durchprobieren.

### `GH_PRIVATE_TOKEN`
- **Host:** github.com
- **User:** TimRudorf
- **Wofür:** Tims private Repos (`TimRudorf/dotfiles`, `TimRudorf/docker-compose`, persönliche Projekte, alles unter github.com/TimRudorf/*)
- **One-shot Push:**
  ```bash
  git -c credential.helper="!f() { echo username=TimRudorf; echo password=$GH_PRIVATE_TOKEN; }; f" push ...
  ```

### `GH_WORK_TOKEN`
- **Host:** `einsatzleitsoftware.ghe.com` (steht in `$GH_WORK_HOST`)
- **Wofür:** EDP-Repos auf der dienstlichen GitHub-Enterprise-Instanz (edp-Skills, PRs/Issues dort, alles EDP-Arbeit)
- **One-shot Push:**
  ```bash
  git -c credential.helper="!f() { echo username=tim; echo password=$GH_WORK_TOKEN; }; f" push ...
  ```

### Entscheidung
- Repo-URL `github.com/TimRudorf/...` → `GH_PRIVATE_TOKEN`
- Repo-URL `einsatzleitsoftware.ghe.com/...` (oder Kontext = EDP-Arbeit) → `GH_WORK_TOKEN`
- Im Zweifel: `git remote -v` prüfen.

### gh-CLI-Sonderfall
`gh` liest standardmäßig `GH_TOKEN`. Wenn du `gh` nutzen willst, vorher `export GH_TOKEN="$GH_PRIVATE_TOKEN"` setzen (oder `$GH_WORK_TOKEN` mit `GH_HOST="$GH_WORK_HOST"`). Tims `.zshrc` hat ggf. einen Default.

## Nextcloud — beide Instanzen nutzbar

Tim hat Jarvis Zugriff auf **beide Nextcloud-Instanzen** als Env-Vars:

- **Privat:** `NC_PRIVATE_HOST` (cloud.timrudorf.de), `NC_PRIVATE_USER` (timrudorf), `NC_PRIVATE_PASSWORD`, `NC_PRIVATE_WEBDAV`
- **Dienstlich:** `NC_WORK_HOST` (einsatzleitsoftware.de/nextcloud), `NC_WORK_USER` (tim.rudorf), `NC_WORK_PASSWORD`, `NC_WORK_WEBDAV`

**Why Zugriff:** Reisepläne, Termine, Familien-/Sport-Termine soll Jarvis erkennen und mitdenken können, ohne dass Tim sie manuell zuruft. Dual-Access (privat/dienstlich) gemäß CONTEXTS.md-Routing.

**Endpoints:**
- **CalDAV:** `${NC_*_HOST}/remote.php/dav/calendars/${NC_*_USER}/`
- **WebDAV:** `${NC_*_HOST}${NC_*_WEBDAV}` für Dateien lesen/schreiben.

**Routing:** privater Kontext (Familie, Sport, Reisen) → `NC_PRIVATE_*`; dienstlich (EDP-Termine) → `NC_WORK_*`.

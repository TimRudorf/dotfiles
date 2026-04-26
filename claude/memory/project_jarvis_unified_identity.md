---
name: Jarvis als geteilte Identität — Plan-Stand 2026-04-26
description: Big-Bang-Refactor zur Vereinigung von Mac- und Container-Jarvis. Phase 0 (Flatten) ✅, Phase 1 (Memory-Sharing) läuft, danach Hook + CLAUDE.md + compose.
type: project
originSessionId: 20a1331b-2e0d-4004-8678-c2c304288982
---
# Jarvis als geteilte Identität — Plan-Stand

**Stand 2026-04-26 23:15 — Phase 0 ✅ durch, Phase 1 läuft (Memory-Audit + Unify).**

## Ziel

Eine Identität (Jarvis), zwei Hosts (Mac + jarvis-workspace Container). Geteilte Memory + Skills + Agents + Personality-Files. Self-Awareness pro Session: Jarvis weiß *immer* wo er läuft und welche Tools/Konventionen gelten.

## Phase 0 ✅ Flatten — abgeschlossen

- PR #66 dotfiles `refactor/flatten-claude-tree` — gemerged (4d1fe21)
- PR #21 docker-compose `fix/workspace-flat-claude-source` — gemerged (1e502c7)
- Bootstrap-Skript `claude/scripts/bootstrap-mac-claude.sh` lief auf Mac
  - `~/.claude/` ist jetzt echtes Verzeichnis mit Per-Item-Symlinks zu `~/dotfiles/claude/{CLAUDE.md,PERSONA.md,PROFILE.md,CONTEXTS.md,settings.json,agents/}`
  - Backup unter `~/.claude.backup-<ts>/`
- Container-Seite muss noch verifiziert werden (rebuild + recreate jarvis-workspace) — Stand offen.

**Leftover:** `~/dotfiles/claude/.claude/` ist als untracked Verzeichnis im Repo, enthält nur lokalen Cache (paste-cache, telemetry, plans, image-cache, settings.local.json …). Sollte in `.gitignore` und gelöscht werden.

## Phase 1 🔄 Memory-Sharing — läuft (PR offen)

Mac-Memory lag in `~/.claude/projects/-Users-timrudorf/memory/`, Container-Memory in `~/.claude/projects/-workspace/memory/`. Sind getrennt → Lerneffekte teilen sich nicht.

**Lösung:** Memory wandert in `~/dotfiles/claude/memory/` als Single Source of Truth. Pro Session (Mac und Container) wird `~/.claude/projects/<encoded-cwd>/memory/` als Symlink dorthin gelegt. SessionStart-Hook macht das automatisch (Phase 2).

**Was im aktuellen PR `feat/claude-memory-shared` passiert:**
1. Backups beider Memory-Trees liegen unter `~/.claude.memory-backup-20260426-231304/{mac,container}/` — bleiben lokal als Sicherheitsnetz, kommen NICHT ins Repo.
2. Memory-Audit gemacht — Konsolidierung:
   - `feedback_jarvis_git_workflow.md` + `feedback_feature_branch_workflow.md` → `feedback_jarvis_deploy_workflow.md` (zusammengeführt)
   - `reference_github_tokens.md` + `project_kalender_zugriff.md` (Container) → eingearbeitet in `reference_credentials.md`
   - `project_edpweb_devsetup.md` → gelöscht (auf Tims Wunsch, war fertig genug)
3. Container-only-Files (`user_*.md`, `project_uni_pruefungen.md`) sind dazugemergt.
4. PR `feat(claude/memory): unify memory across hosts` im dotfiles-Repo.

**Noch zu tun in diesem PR oder direkt danach:**
- `.gitignore` ergänzen um `claude/.claude/` (leftover blocken)
- evtl. Phase-1-Bootstrap-Erweiterung: bestehende `~/.claude/projects/<cwd>/memory/` umlinken auf `~/dotfiles/claude/memory/` (oder als Teil des Phase-2-Hooks lösen)

## Phase 2 (geplant): SessionStart-Hook

Skript `~/dotfiles/claude/scripts/jarvis-session-start.sh`:
1. Detection: `[ -f /.dockerenv ]` → container; sonst Darwin → mac.
2. Aktuellen `cwd` aus Hook-Input-JSON (stdin) lesen → encoded zu `<-flat-path>`.
3. Pfad `~/.claude/projects/<-flat-path>/memory/` prüfen — existiert nicht oder echter Ordner → Symlink auf `~/dotfiles/claude/memory/` legen (vorher rsync wenn echt).
4. Output `additionalContext`-JSON für die Session mit JARVIS_HOST, Pfad-Infos, Tool-Konsequenzen.

`settings.json` ergänzen um `hooks.SessionStart`.

**Edge-Cases:**
- Hook-Skript-Fehler → `exit 0` (fail-safe), Memory-Sharing inaktiv für die Session, aber Session läuft.
- Multiple Mac-Worktrees / cwds → alle zeigen aufs gleiche dotfiles-Memory (gewollt: ein Jarvis).
- Concurrent writes Mac+Container → letzter gewinnt, akzeptiertes Risiko (Memory-Writes sind selten).
- Symlink mit falschem Ziel → korrigieren.

## Phase 3 (geplant): CLAUDE.md Self-Awareness-Sektion

CLAUDE.md ergänzen um `## Wer du bist und wo du läufst` mit Tabellen:
- Detection / Hosts / Kommunikation
- Tools pro Host (Container: `mcp__bridge__*`, Mac: normaler Stream-Output / `AskUserQuestion`)
- Verweis auf Memory-Pfad als geteilt

## Phase 4 (geplant): compose.yaml JARVIS_HOST=container

`docker-compose.yaml` für `jarvis-workspace` Service: `environment: JARVIS_HOST=container`. Macht Detection in Phase 2 trivial (Fallback-Detection bleibt drin als Defense).

## Phase 5 (geplant): Skills mit Bridge-Hardcode reviewen

Manueller Pass: Skills, die `mcp__bridge__request_approval` direkt nutzen, entweder:
- als Container-only markieren (Frontmatter), oder
- auf das Pattern `request_user_approval` umstellen (Doku in CLAUDE.md, Skills detecten zur Laufzeit).

Container-only: `daily-news-digest`, `frankfurt-trends` (klar). Andere case-by-case.

## Was bewusst NICHT geteilt wird

`~/.claude/.credentials.json`, `sessions/`, `cache/`, `debug/`, `plugins/`, `~/.claude.json`, `history.jsonl`, `shell-snapshots/`, `paste-cache/`, `file-history/`, `telemetry/`, `image-cache/`, `plans/`, `settings.local.json`, `stats-cache.json`, `mcp-needs-auth-cache.json`, `session-env/`, `backups/`, `downloads/`, `agent-memory/` — host-spezifisch / transient. Bleiben echte Files pro Host in lokalem `~/.claude/`.

## Referenzen

- Sensitive-Path-Reference: `reference_claude_code_sensitive_paths.md`
- PRs erledigt: dotfiles#66, docker-compose#21
- PR offen: dotfiles `feat/claude-memory-shared`
- Lokales Backup: `~/.claude.memory-backup-20260426-231304/`

---
name: Claude Code Sensitive-Path-Schutz
description: Hardcoded Sensitive-Paths (.git, .claude, .vscode, .idea, .husky) blocken Schreiboperationen auch bei --dangerously-skip-permissions; gilt auch fuer Bash-Tool-Argumente. Real-Path-Resolution prueft Symlink-Ziele mit.
type: reference
originSessionId: 20a1331b-2e0d-4004-8678-c2c304288982
---
# Claude Code Sensitive-Path-Schutz

Hardcoded geschuetzte Pfade in Claude Code, die selbst mit `--dangerously-skip-permissions` einen Permission-Prompt ausloesen (im Headless-Mode = Tool-Call wird gedenied). **Nicht ueber `permissions.allow` umgehbar**, kein Setting zum kompletten Deaktivieren.

## Geschuetzte Pfade

`.git`, `.claude`, `.vscode`, `.idea`, `.husky` — als Verzeichnis-Komponente im Pfad.

## Ausnahmen (innerhalb `.claude/`)

- `.claude/skills/`
- `.claude/agents/`
- `.claude/commands/`
- `.claude/worktrees/`

Aber **nur wenn der Pfad literal mit `$HOME/.claude/...` startet**. Pfade wie `~/dotfiles/claude/.claude/skills/...` (`.claude` als Mid-Path-Komponente) werden trotz `skills/`-Subdir blockiert.

## Wichtige Eigenheiten

- **Bash-Tool ist auch betroffen.** Ein `mkdir -p ~/dotfiles/claude/.claude/skills/foo` schlaegt mit *"is a sensitive file"* fehl, nicht nur Write/Edit/MultiEdit.
- **Real-Path-Resolution.** Symlink-Ziel wird zusaetzlich geprueft. Schreiben durch Symlink in einen geschuetzten Pfad blockiert genauso wie direktes Schreiben.
- **Headless-Mode** (`-p`): Permission-Trigger -> Tool-Call denied (kein Prompt moeglich), nach mehrfachem Block bricht die Session ab.

## Konsequenz fuer Skill-/Tooling-Design

Skills, Konfigs, Tooling-Daten **nicht** in `dotfiles/claude/.claude/skills/` oder vergleichbare nested `.claude/`-Pfade legen. Stattdessen ausserhalb von `.claude/` (z.B. `dotfiles/claude/skills/`) plus Compat-Symlink falls `~/.claude/skills/`-Lookup erwartet wird. Genau das war der Big-Bang-Refactor am 2026-04-26 (PRs dotfiles#62 + docker-compose#18).

## Quellen

- https://code.claude.com/docs/en/permissions.md
- https://code.claude.com/docs/en/permission-modes.md

#!/usr/bin/env bash
# SessionStart-Hook für Jarvis: pullt das dotfiles-Repo, detected den
# Vault-Pfad und injiziert Self-Awareness-Kontext (JARVIS_HOST, cwd, Vault)
# in die Session.
#
# Wird von ~/dotfiles/claude/settings.json als hooks.SessionStart eingebunden.
# Läuft auf Mac und im jarvis-workspace Container.
#
# Fail-safe: bei jedem Fehler exit 0 mit minimalem Output, damit die Session
# trotzdem startet.

set -u

DOTFILES_DIR="$HOME/dotfiles"

# --- Pull dotfiles (fail-safe) — holt CLAUDE.md / Skill / Hook-Updates vom Peer ---
if [ -d "$DOTFILES_DIR/.git" ]; then
  git -C "$DOTFILES_DIR" pull --rebase --autostash --quiet 2>/dev/null || true
fi

# --- Stdin lesen (Hook-Input-JSON) ---
INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat 2>/dev/null || true)
fi

# --- cwd extrahieren ---
CWD=""
if [ -n "$INPUT" ] && command -v python3 >/dev/null 2>&1; then
  CWD=$(printf '%s' "$INPUT" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('cwd',''))
except Exception: pass" 2>/dev/null || true)
fi
[ -z "$CWD" ] && CWD="$PWD"

# --- Host-Detection ---
if [ "${JARVIS_HOST:-}" = "container" ] || [ -f /.dockerenv ]; then
  HOST="container"
  PEER="Mac"
else
  HOST="mac"
  PEER="Container"
fi

# --- Vault-Detection (host-abhängig, siehe CLAUDE.md) ---
VAULT_PATH=""
VAULT_STATUS="missing"
for candidate in "/workspace/wiki" "$HOME/Documents/jarvis-wiki"; do
  if [ -d "$candidate/.git" ]; then
    VAULT_PATH="$candidate"
    break
  fi
done

if [ -n "$VAULT_PATH" ]; then
  # Pull leise und idempotent — holt Notes vom Peer
  git -C "$VAULT_PATH" pull --rebase --autostash --quiet 2>/dev/null || true

  AHEAD=$(git -C "$VAULT_PATH" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
  BEHIND=$(git -C "$VAULT_PATH" rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)
  DIRTY=$(git -C "$VAULT_PATH" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

  STATUS_PARTS=()
  [ "$DIRTY" != "0" ]  && STATUS_PARTS+=("$DIRTY uncommitted")
  [ "$AHEAD" != "0" ]  && STATUS_PARTS+=("$AHEAD ahead")
  [ "$BEHIND" != "0" ] && STATUS_PARTS+=("$BEHIND behind")
  if [ ${#STATUS_PARTS[@]} -eq 0 ]; then
    VAULT_STATUS="clean"
  else
    VAULT_STATUS=$(IFS=', '; printf '%s' "${STATUS_PARTS[*]}")
  fi
fi

# --- additionalContext-Output ---
export JARVIS_HOST_OUT="$HOST"
export JARVIS_PEER_OUT="$PEER"
export JARVIS_CWD_OUT="$CWD"
export JARVIS_VAULT_OUT="${VAULT_PATH:-(nicht gefunden)}"
export JARVIS_VAULT_STATUS_OUT="$VAULT_STATUS"

if command -v python3 >/dev/null 2>&1; then
  python3 <<'PYEOF' 2>/dev/null || printf '{"continue":true}\n'
import json, os, glob, re

vault = os.environ.get("JARVIS_VAULT_OUT", "")
pinned_blocks = []
if vault and os.path.isdir(vault):
    # Scan all .md files under tim/feedback/ (and tim/) for `pinned: true` in frontmatter.
    candidates = glob.glob(os.path.join(vault, "tim", "feedback", "*.md"))
    candidates += glob.glob(os.path.join(vault, "tim", "*.md"))
    for path in sorted(set(candidates)):
        try:
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
        except Exception:
            continue
        m = re.match(r"^---\n(.*?)\n---\n(.*)$", content, re.DOTALL)
        if not m:
            continue
        frontmatter, body = m.group(1), m.group(2)
        if not re.search(r"^pinned:\s*true\s*$", frontmatter, re.MULTILINE):
            continue
        title_m = re.search(r"^(?:title|name):\s*(.+?)\s*$", frontmatter, re.MULTILINE)
        title = title_m.group(1).strip() if title_m else os.path.basename(path)
        rel = os.path.relpath(path, vault)
        pinned_blocks.append(f"### {title}\n_(Quelle: `{rel}`)_\n\n{body.strip()}")

ctx_parts = [
    "## Wo du gerade läufst\n",
    f"- **JARVIS_HOST:** {os.environ['JARVIS_HOST_OUT']}",
    f"- **cwd:** {os.environ['JARVIS_CWD_OUT']}",
    f"- **Vault:** {os.environ['JARVIS_VAULT_OUT']}",
    f"- **Vault-Status:** {os.environ['JARVIS_VAULT_STATUS_OUT']}",
    "",
    "Persistente Erkenntnisse gehen ins Vault (siehe CLAUDE.md + "
    "$VAULT/SCHEMA.md). Schreibvorgänge im Vault werden via PostToolUse-Hook "
    "automatisch committet und gepusht — der Peer-Host sieht sie beim "
    "nächsten Pull. Beim Schreiben daran denken, dass Erkenntnisse "
    "hostübergreifend gelten — also keine host-spezifischen Pfade ohne "
    "Klammerzusatz aufschreiben.",
]

if pinned_blocks:
    ctx_parts.append("")
    ctx_parts.append("## Pflicht-Verhaltensregeln (pinned aus dem Vault)")
    ctx_parts.append("")
    ctx_parts.append(
        "Diese Notes sind als `pinned: true` markiert und müssen in jeder "
        "Session aktiv beachtet werden. Sie überschreiben Default-Verhalten "
        "aus dem System-Prompt, wenn sie kollidieren."
    )
    ctx_parts.append("")
    ctx_parts.extend(pinned_blocks)

ctx = "\n".join(ctx_parts)

print(json.dumps({
    "continue": True,
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": ctx,
    },
}))
PYEOF
else
  printf '{"continue":true}\n'
fi

exit 0

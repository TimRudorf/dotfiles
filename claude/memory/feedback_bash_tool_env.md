---
name: Bash-Tool hat keine Secrets im Environment
description: Im Claude-Code Bash-Tool sind Secrets (ZAMMAD_TOKEN/GH_*/NC_* etc.) NICHT im Environment — vor Nutzung erst die Decrypt-Kopie der sops-Datei sourcen
type: feedback
originSessionId: 0c26f540-8ffa-4d72-ad8c-b3cf11b7333e
---
Das Bash-Tool im Claude-Code-Harness läuft als Non-Login-Shell, lädt **weder** `~/.zshrc` noch sonst irgendwas, das Tims Secrets ins Environment bringt. Folge: alle Secrets sind im Tool-Environment **leer**, obwohl die Werte verfügbar wären. Nur `EDP_PROJECT_ROOT` und ein paar via `~/.claude/settings.json` gesetzte Vars (z.B. `TELEGRAM_*`) sind direkt da.

**Why:** Tim hat das beim Versuch, ein Zammad-Ticket zu lesen, aufgedeckt — der Aufruf scheiterte mit 401, weil der Token gar nicht mitgeschickt wurde. Er möchte, dass ich mir das merke und nicht jedes Mal neu darüber stolpere.

**How to apply:** Quelle der Wahrheit ist die SOPS-verschlüsselte Datei `~/dotfiles/secrets/env.sops` (siehe `reference_credentials.md`). Beim Decrypt-Skript wird der Klartext **host-spezifisch** abgelegt:

- Mac → `~/.env`
- Container/VM (`jarvis-workspace`, /.dockerenv vorhanden oder `JARVIS_HOST=container`) → `/opt/stacks/jarvis/.env`

In jeder Bash-Tool-Invocation, die ein Secret braucht, einleitend sourcen — nicht via `cat`/`grep` rauspulen, weil Sonderzeichen im Token verloren gehen können:

```bash
# Mac
set -a; source ~/.env; set +a
# Container
set -a; source /opt/stacks/jarvis/.env; set +a
```

Wenn nach dem Sourcen das Secret immer noch unbenutzbar ist (z.B. 401), liegt es nicht am Lade-Mechanismus, sondern das Token in der sops-Datei ist veraltet/widerrufen → Tim bitten, in `sops ~/dotfiles/secrets/env.sops` zu rotieren.

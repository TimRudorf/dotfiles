---
name: Bash-Tool hat keine .env geladen
description: Im Claude-Code Bash-Tool sind ZAMMAD_TOKEN/GH_*/NC_* etc. NICHT im Environment — vor jedem Aufruf, der Secrets braucht, .env explizit sourcen
type: feedback
originSessionId: 0c26f540-8ffa-4d72-ad8c-b3cf11b7333e
---
Das Bash-Tool im Claude-Code-Harness läuft als Non-Login-Shell und lädt **weder** `~/.zshrc` noch `~/.env`. Folge: alle in `~/.env` (Mac) bzw. `/opt/stacks/jarvis/.env` (Container) abgelegten Secrets — `ZAMMAD_HOST/TOKEN`, `GH_*_TOKEN`, `NC_*`, `OPENAI_API_KEY`, etc. — sind im Tool-Environment **leer**, obwohl die Datei existiert. Nur `EDP_PROJECT_ROOT` und ein paar via Settings.json gesetzte Vars (z.B. `TELEGRAM_*`) sind direkt da.

**Why:** Tim hat das beim Versuch, ein Zammad-Ticket zu lesen, aufgedeckt — der erste Aufruf scheiterte still mit einer leeren Variable; der zweite ohne explizites Sourcen produzierte 401-Antworten, weil der Token gar nicht mitgeschickt wurde. Er möchte, dass das nicht jedes Mal neu erlebt wird.

**How to apply:** In **jeder** Bash-Tool-Invocation, die ein Secret aus der zentralen `.env` braucht, einleitend sourcen — nicht via `cat /grep` rauspulen, weil Sonderzeichen im Token verloren gehen können:

```bash
# Mac
set -a; source ~/.env; set +a
# Container (jarvis-workspace)
set -a; source /opt/stacks/jarvis/.env; set +a
```

Hostauswahl: Wenn `/.dockerenv` existiert oder `JARVIS_HOST=container`, dann VM-Pfad; sonst Mac-Pfad. Quelle der Wahrheit für die Werte bleibt `~/dotfiles/secrets/env.sops` — siehe `reference_credentials.md`.

Wenn nach dem Sourcen das Secret immer noch unbenutzbar ist (z.B. 401), ist es nicht der Lade-Mechanismus, sondern das Token in der sops-Datei ist veraltet/widerrufen → Tim bitten zu rotieren (`sops ~/dotfiles/secrets/env.sops`).

---
name: Wie ich an Tims Credentials komme
description: Bash-Tool hat keine Secrets im Environment — host-abhängig die richtige Decrypt-Kopie sourcen, dann sind ZAMMAD_TOKEN/GH_*/NC_* etc. da
type: feedback
originSessionId: 0c26f540-8ffa-4d72-ad8c-b3cf11b7333e
---
Das Bash-Tool startet als Non-Login-Shell ohne Tims Secrets im Environment. Bevor ich Aufrufe mache, die `ZAMMAD_TOKEN`, `GH_*_TOKEN`, `NC_*`, `OPENAI_API_KEY` etc. brauchen, muss ich die passende Decrypt-Datei sourcen:

```bash
# Mac
set -a; source ~/.env; set +a

# Container / VM (wenn /.dockerenv existiert oder $JARVIS_HOST=container)
set -a; source /opt/stacks/jarvis/.env; set +a
```

Das ist alles — danach sind alle Secrets als normale Env-Vars verfügbar.

**Why:** Tim hat das beim ersten Zammad-Lese-Versuch aufgedeckt (Aufruf produzierte 401, weil Token leer war). Er will, dass ich diesen einen Schritt automatisch im Kopf habe und nicht jedes Mal neu rausfinde.

**How to apply:** Bei jeder neuen Bash-Tool-Invocation, die ein Secret braucht, mit dem Source-Befehl beginnen. Nicht `cat`/`grep` auf die Datei — Sonderzeichen im Token gehen verloren.

Hintergrund (nicht zur Anwendung nötig, nur zur Einordnung): Quelle der Wahrheit ist `~/dotfiles/secrets/env.sops` (SOPS-verschlüsselt). Wenn nach dem Sourcen ein Secret 401 liefert, ist nicht der Lade-Mechanismus kaputt, sondern das Token wurde rotiert/widerrufen → Tim bitten, mit `sops ~/dotfiles/secrets/env.sops` zu aktualisieren.

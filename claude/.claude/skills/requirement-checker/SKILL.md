---
name: requirement-checker
user-invocable: false
description: Validates skill prerequisites (Voraussetzungen). Automatically invoked when a skill declares requirements with type prefixes (Env, Tools, Datei, Projekt). Checks environment variables, tool availability, file existence, and project paths. Reports fulfillment status and remediation options.
---

# Voraussetzungen validieren

Prüft die deklarativen Voraussetzungen eines Skills. Jede Voraussetzung ist entweder ERFÜLLT oder NICHT ERFÜLLT.

## Prüflogik pro Typ-Prefix

### Env: Umgebungsvariablen
Prüfe ob jede Variable gesetzt und nicht leer ist (`test -n "$VAR"`).

**Auto-Source bei Fehlschlag:** Das Bash-Tool startet als Non-Login-Shell ohne Tims Secrets im Environment. Bevor eine fehlende Env-Var als nicht-erfüllt gemeldet wird, EINMAL die host-aware Decrypt-Datei sourcen und die Variable erneut prüfen:

```bash
# Host-aware Source — wirkt sowohl auf Mac als auch in Container/VM
set -a; source ~/.env 2>/dev/null || source /opt/stacks/jarvis/.env 2>/dev/null; set +a
```

Nach dem Source-Versuch erneut `test -n "$VAR"`. Wenn die Variable danach immer noch leer ist → echte Nicht-Erfüllung (Token rotiert/widerrufen oder gar nicht im SOPS-Vault). Dann erst abbrechen.

Das ist ein einmaliger Source pro Skill-Aufruf, harmlos wenn die Vars schon gesetzt sind, und löst den häufigsten Cause für `Env: X — nicht gesetzt`-Fehlschläge ohne dass jeder Skill das selbst tun muss. Hintergrund: Volltext in `~/Documents/jarvis-wiki/tim/feedback/bash-tool-env.md`.

### Tools: Kommandozeilen-Tools
Prüfe ob jedes Tool im PATH verfügbar ist (`command -v tool`).

### Datei: Dateien/Verzeichnisse
Prüfe ob der Pfad existiert (`test -e path`). Tilde (`~`) zu `$HOME` auflösen.

### Projekt: Projektpfade
Prüfe ob mindestens ein Match für den Glob-Pfad existiert (z.B. `~/dev/EDP/*`).

## Ergebnis

### Alle erfüllt
Kurze Bestätigung, dann direkt mit dem Skill fortfahren.

### Fehlschlag
Auflisten was fehlt mit konkreter Angabe (erwartet vs. gefunden) und Hinweis wie es behoben werden kann. Darstellungsformat frei wählen — Hauptsache klar erkennbar was fehlt und was erfüllt ist.

**WICHTIG: Bei Fehlschlag wird der aufrufende Skill SOFORT und VOLLSTÄNDIG abgebrochen. Keine Teilausführung, keine Workarounds, keine weiteren Schritte. Nur die Fehlermeldung ausgeben und stoppen.**

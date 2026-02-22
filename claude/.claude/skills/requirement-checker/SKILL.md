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

### Tools: Kommandozeilen-Tools
Prüfe ob jedes Tool im PATH verfügbar ist (`command -v tool`).

### Datei: Dateien/Verzeichnisse
Prüfe ob der Pfad existiert (`test -e path`). Tilde (`~`) zu `$HOME` auflösen.

### Projekt: Projektpfade
Prüfe ob mindestens ein Match für den Glob-Pfad existiert (z.B. `~/Develop/EDP/*`).

## Ergebnis

### Alle erfüllt
Kurze Bestätigung, dann direkt mit dem Skill fortfahren:
```
✅ Alle Voraussetzungen erfüllt.
```

### Fehlschlag
Auflisten was fehlt mit konkreter Angabe (erwartet vs. gefunden) und Hinweis wie es behoben werden kann.

**WICHTIG: Bei Fehlschlag wird der aufrufende Skill SOFORT und VOLLSTÄNDIG abgebrochen. Keine Teilausführung, keine Workarounds, keine weiteren Schritte. Nur die Fehlermeldung ausgeben und stoppen.**

Beispiel-Ausgabe bei Fehlschlag:
```
❌ Voraussetzungen nicht erfüllt:
- Env: `ZAMMAD_TOKEN` nicht gesetzt → In `.env` oder Shell-Profil setzen
- Tools: `jq` nicht gefunden → `sudo pacman -S jq`

✅ Erfüllt:
- Env: `ZAMMAD_HOST`
- Tools: `curl`

⛔ Skill-Ausführung abgebrochen. Fehlende Voraussetzungen zuerst beheben.
```

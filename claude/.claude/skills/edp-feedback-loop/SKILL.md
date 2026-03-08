---
name: edp-feedback-loop
description: Deploy, compile and verify changes on the Dev-VM via browser. Use when the user asks to "überprüfen", "testen", "verifizieren", "feedback loop", "deploy und testen", or wants to see changes live in the browser.
disable-model-invocation: true
argument-hint: [was zu überprüfen ist]
allowed-tools: Bash(source *edp*), Bash(devvm *), Bash(ssh *), Bash(PLAYWRIGHT_MCP_IGNORE_HTTPS_ERRORS=1 playwright-cli:*)
---

# EDP Feedback Loop

Deploye Änderungen auf die Dev-VM, kompiliere bei Bedarf und verifiziere das Ergebnis im Browser via Playwright.

## Voraussetzungen
- Tools: `edp`, `devvm`, `playwright-cli`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Schritt 1: DevVM sicherstellen

```bash
devvm status
```

Falls nicht läuft: `devvm start` und warten bis SSH erreichbar ist (`ssh eifert-dev echo ok`).

## Schritt 2: Deploy

```bash
source ~/.edp_helpers.sh && edp edpweb deploy
```

## Schritt 3: Compile (bedingt)

Nur wenn Backend-Änderungen (`.pas`-Dateien) im aktuellen Diff vorliegen:

```bash
source ~/.edp_helpers.sh && edp edpweb compile
```

Prüfe den Compile-Output auf Erfolg. Bei Fehler abbrechen und User informieren.

## Schritt 4: Anmeldung via Playwright

Browser öffnen und Login durchführen:

```bash
PLAYWRIGHT_MCP_IGNORE_HTTPS_ERRORS=1 playwright-cli open --browser=chromium https://${EDP_VM_HOST:-192.168.122.46}/
```

**Wichtig**: Alle nachfolgenden `playwright-cli`-Befehle ebenfalls mit `PLAYWRIGHT_MCP_IGNORE_HTTPS_ERRORS=1` prefixen.

Snapshot lesen und Login-Formular ausfüllen:
- Feld `benutzer` → `"demo"`
- Feld `passwort` → `"demo"`
- Dropdown Funktion → `"Einsatzleiter"` oder `"EL"` wählen (was im Dropdown vorhanden ist)
- Absenden

Nach Submit prüfen ob die Anmeldung erfolgreich war (Weiterleitung zur Hauptseite).

## Schritt 5: Navigation & Verifikation

Navigiere zur relevanten Seite basierend auf `$ARGUMENTS`. Nutze Snapshots, Screenshots und `eval` um den gewünschten Zustand zu prüfen.

Typische Prüfungen:
- Seitenstruktur und Inhalte via Snapshot
- Visuelle Darstellung via Screenshot
- Daten und DOM-Zustand via `eval`
- Netzwerk-Antworten via `network`

## Schritt 6: Einschätzung

Ergebnis bewerten und User informieren:
- **Erfolgreich**: Was wurde geprüft, was funktioniert wie erwartet
- **Probleme gefunden**: Konkrete Beschreibung + Vorschlag für Änderungen
- **Screenshots** als Beleg anhängen wenn sinnvoll

Browser schließen:

```bash
PLAYWRIGHT_MCP_IGNORE_HTTPS_ERRORS=1 playwright-cli close
```

Abschließend `skill-optimize` mit `edp-feedback-loop` aufrufen.

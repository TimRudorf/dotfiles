---
name: skill-create
description: Creates a new Claude Code skill with optimal structure. Use when asked to create a skill, generate a slash command, or set up a new SKILL.md.
disable-model-invocation: true
argument-hint: [skill-name] [description of what the skill should do]
---

# Skill erstellen

Erstellt einen neuen Claude Code Skill mit optimaler Struktur basierend auf Name und Beschreibung.

## Schritt 1: Argumente parsen

Aus `$ARGUMENTS` extrahieren:
- **Skill-Name**: Erstes Wort (lowercase, Bindestriche erlaubt)
- **Beschreibung**: Alles nach dem ersten Wort

Falls `$ARGUMENTS` leer oder unvollständig: Nach Name und Beschreibung fragen. Kommunikationsweg gemäß `CLAUDE_COMM_CHANNEL` wählen (siehe `.shared/communication.md`).

## Schritt 2: Scope abfragen

Den Scope bestimmen (Kommunikationsweg gemäß `CLAUDE_COMM_CHANNEL`, siehe `.shared/communication.md`):

| Option | Pfad | Wann |
|--------|------|------|
| **User-Scope** | `~/.claude/skills/{name}/SKILL.md` | Persönliche Skills, überall verfügbar |
| **Projekt-Scope** | `.claude/skills/{name}/SKILL.md` | Projektspezifisch, wird mit dem Repo geteilt |

## Schritt 3: Kollision prüfen

Prüfen ob `{scope}/{name}/SKILL.md` bereits existiert. Falls ja: User informieren und abbrechen oder Überschreiben bestätigen lassen.

## Schritt 4: SKILL.md generieren

Lies die Best Practices unter `~/.claude/skills/.shared/skill-best-practices.md` und wende sie beim Generieren der SKILL.md an.

Basierend auf der Beschreibung autonom entscheiden:

### Frontmatter
- `name`: Der gewählte Skill-Name
- `description`: Aus der Beschreibung eine präzise Description in dritter Person ableiten, mit Trigger-Keywords. Max 1024 Zeichen.
- `disable-model-invocation`: `true` setzen wenn der Skill Side-Effects hat (Dateien schreiben, deployen, senden, committen). Sonst weglassen.
- `user-invocable`: Nur explizit auf `false` setzen wenn der Skill reines Hintergrundwissen ist. Sonst weglassen (default: true).
- `allowed-tools`: Nur setzen wenn der Skill spezifische Tools braucht. Restriktiv wählen.
- `argument-hint`: Setzen wenn der Skill Parameter erwartet.
- Weitere Felder (`model`, `context`, `agent`) nur setzen wenn die Beschreibung es nahelegt.

### Body

Die Zielstruktur orientiert sich am SKILL.md-Format (siehe `~/.claude/skills/.shared/skill-best-practices.md`, Abschnitt 9):

```
# Titel
Kurzbeschreibung.

## Voraussetzungen          ← deklarativ, optional
- Env: `VAR1`, `VAR2`
- Tools: `cmd1`, `cmd2`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Schritt 1: Kern-Logik    ← direkt ins Wesentliche
...

## Schritt N: Letzter Schritt
...

Abschließend `skill-optimize` mit `skill-name` aufrufen.
```

- Klare Schritt-für-Schritt-Anweisungen im Imperativ
- `$ARGUMENTS` für Parameter-Substitution nutzen wo sinnvoll
- Unter 500 Zeilen halten
- **Datenbeschaffung vs. Schreibaktionen trennen**: Wenn der Skill externe Daten benötigt (APIs, Tickets, Repos, etc.), die Datenbeschaffung als eigenen Schritt formulieren. Dabei beschreiben **was** gebraucht wird und in **welchem Format** (JSON-Beispiel mit minimalen Feldern). Explizit benennen was **nicht** benötigt wird. Keine konkreten Lese-Befehle (`curl`, `gh api`) in diesen Schritten — der Main-Agent entscheidet selbst ob er die Daten delegiert oder selbst beschafft. Schreibaktionen (erstellen, ändern, senden) bleiben als konkrete Befehle im Skill.
- Bei komplexen Skills: Hinweis auf separate Dateien (reference.md etc.) die der User später ergänzen kann
- **Voraussetzungen**: Falls der Skill Env-Variablen, Tools, Dateien oder Projektpfade benötigt, eine **Voraussetzungen-Sektion** mit deklarativer Auflistung (Typ-Prefix: `Env`, `Tools`, `Datei`, `Projekt`) generieren + Verweis auf `requirement-checker` Skill. **Keinen** inline Validierungscode (Schritt 0) generieren.
- **Skill-Optimierung**: Am Ende der SKILL.md den Einzeiler `Abschließend \`skill-optimize\` mit \`{skill-name}\` aufrufen.` einfügen.

## Schritt 5: Dateien erstellen

1. Verzeichnis `{scope}/{name}/` erstellen
2. `SKILL.md` schreiben

## Schritt 6: Ergebnis anzeigen

Die generierte SKILL.md dem User vollständig anzeigen mit Hinweis:
- Skill ist sofort verfügbar unter `/{name}`
- SKILL.md kann jederzeit manuell angepasst werden
- Bei komplexen Skills: Zusätzliche Dateien (reference.md, scripts/) können im Skill-Verzeichnis ergänzt werden

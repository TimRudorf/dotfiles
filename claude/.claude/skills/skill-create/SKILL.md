---
name: skill-create
description: Creates a new Claude Code skill with optimal structure. Use when asked to create a skill, generate a slash command, or set up a new SKILL.md.
argument-hint: [skill-name] [description of what the skill should do]
---

# Skill erstellen

Erstellt einen neuen Claude Code Skill mit optimaler Struktur basierend auf Name und Beschreibung.

## Schritt 1: Argumente parsen

Aus `$ARGUMENTS` extrahieren:

- **Skill-Name**: Erstes Wort (lowercase, Bindestriche erlaubt)
- **Beschreibung**: Alles nach dem ersten Wort

Falls `$ARGUMENTS` leer oder unvollständig: Nach Name und Beschreibung fragen.

## Schritt 2: Scope und Ziel-Pfad bestimmen

Es gibt zwei Scopes:

| Scope             | Wann                                                |
| ----------------- | --------------------------------------------------- |
| **User-Scope**    | Persönliche Skills, überall verfügbar (Default)     |
| **Projekt-Scope** | Projektspezifisch, wird mit dem Repo geteilt        |

**User-Scope: Pfad-Resolution**

User-Skills werden bei Tim grundsätzlich im Dotfiles-Repo gepflegt (Single Source of Truth, persistent über Container-Rebuilds, versioniert). `~/.claude/skills/` ist nicht überall der korrekte Schreib-Pfad:

- **Mac**: `~/.claude` ist ein Symlink auf `~/dotfiles/claude/.claude/` — Schreiben unter beiden Pfaden landet im selben Inode (Dotfiles-Repo).
- **jarvis-workspace Container**: `~/.claude/` ist ein **echtes** Verzeichnis, das beim Container-Start vom entrypoint aus den Dotfiles-Symlinks neu aufgebaut wird (`rm -rf ~/.claude/skills/` + Re-Symlinks). Direkter Write nach `~/.claude/skills/<name>/` würde **beim nächsten Container-Restart silent verschwinden** — und triggert vorher den Sensitive-Path-Schutz von Claude Code.

Daher: Wenn `~/dotfiles/claude/.claude/skills/` existiert und schreibbar ist, ist **das** der kanonische User-Scope-Pfad — sonst Fallback auf `~/.claude/skills/`.

Resolved Pfade:

```
USER_SCOPE_TARGET:
  if  [ -d ~/dotfiles/claude/.claude/skills ] && [ -w ~/dotfiles/claude/.claude/skills ]
  then ~/dotfiles/claude/.claude/skills/{name}/SKILL.md
  else ~/.claude/skills/{name}/SKILL.md

PROJECT_SCOPE_TARGET:  .claude/skills/{name}/SKILL.md   (im aktuellen Projekt)
```

Wähle den Scope (User default) und merke dir Ziel-Pfad und ob das Dotfiles-Setup aktiv ist (für Schritt 6/7).

## Schritt 3: Kollision prüfen

Prüfen ob der Ziel-Pfad bereits existiert. Falls ja: User informieren und abbrechen oder Überschreiben bestätigen lassen.

Bei aktivem Dotfiles-Setup zusätzlich prüfen, ob `~/.claude/skills/{name}` bereits als Datei oder anderer Symlink existiert — das wäre ein Inkonsistenz-Hinweis und sollte vor dem Weitermachen geklärt werden.

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

1. Verzeichnis am Ziel-Pfad anlegen (`mkdir -p`)
2. `SKILL.md` schreiben

## Schritt 6: Symlink in ~/.claude/skills/ (nur Dotfiles-Setup im Container)

Nur ausführen, wenn das Dotfiles-Setup aktiv war (Schritt 2) **und** `~/.claude/skills/{name}` noch nicht auf den neuen Skill zeigt:

```bash
ln -sfn ~/dotfiles/claude/.claude/skills/{name} ~/.claude/skills/{name}
```

Auf dem Mac (`~/.claude` ist Symlink auf Dotfiles) ist dieser Schritt überflüssig — der Skill ist über den ganz-Symlink schon sichtbar. Ein zusätzlicher Symlink würde dort redundant zu sich selbst zeigen, also nicht ausführen.

Verifikation: `[ -f ~/.claude/skills/{name}/SKILL.md ]` muss true sein.

## Schritt 7: In Dotfiles-Repo committen + pushen (nur Dotfiles-Setup)

Nur wenn der Skill im Dotfiles-Repo gelandet ist (Schritt 2). Sonst: User darauf hinweisen, dass der Skill nur lokal lebt und nicht persistent ist.

1. Im Dotfiles-Repo (`~/dotfiles`) den neuen Pfad stagen:
   ```bash
   cd ~/dotfiles
   git add claude/.claude/skills/{name}/
   ```
2. Branch-Status prüfen — wenn auf `main`, neuen Feature-Branch `feat/skill-{name}` anlegen, sonst auf aktuellem Branch bleiben.
3. Commit erstellen mit Subject `feat(skill): {name}` und einer kurzen Body-Zeile aus der Description.
4. **Push erfordert Approval**: Der Push schreibt in den remote `TimRudorf/dotfiles` und ist damit dauerhaft sichtbar. Vor dem `git push` mit `mcp__bridge__request_approval` (Bridge-Kontext) bzw. einer expliziten User-Rückfrage (Mac-CLI-Kontext) den Push freigeben lassen.
5. Nach dem Push den Branch und PR-URL melden, falls ein PR-Workflow Sinn macht (User-Skill ist meist ein simpler Push auf Feature-Branch — der User entscheidet, ob er direkt mergen will).

## Schritt 8: Ergebnis anzeigen

Die generierte SKILL.md dem User vollständig anzeigen mit Hinweis:

- Skill ist sofort verfügbar unter `/{name}` (Symlink-Schritt 6 hat das sichergestellt)
- SKILL.md kann jederzeit manuell angepasst werden
- Bei komplexen Skills: Zusätzliche Dateien (reference.md, scripts/) können im Skill-Verzeichnis ergänzt werden
- Bei Dotfiles-Setup: Skill liegt unter `~/dotfiles/claude/.claude/skills/{name}/` (nicht direkt unter `~/.claude/skills/`) — Bearbeitungen bitte am kanonischen Pfad vornehmen

# Skill Best Practices – Referenz

## 1. SKILL.md Aufbau

### Frontmatter (YAML)

| Feld | Pflicht | Zweck |
|------|---------|-------|
| `name` | Nein* | Lowercase, Zahlen, Bindestriche. Max 64 Zeichen. Fallback = Verzeichnisname |
| `description` | Empfohlen | Wann/wozu der Skill genutzt wird. Max 1024 Zeichen. Entscheidend für Auto-Invocation |
| `disable-model-invocation` | Nein | `true` = Claude ruft den Skill nie selbst auf (Side-Effect-Skills) |
| `user-invocable` | Nein | `false` = Versteckt aus `/`-Menü (Hintergrundwissen-Skills) |
| `allowed-tools` | Nein | Tools ohne Nachfrage erlauben, z.B. `Read, Grep, Bash(python *)` |
| `model` | Nein | Modell überschreiben: `opus`, `sonnet`, `haiku` |
| `context` | Nein | `fork` = Läuft in isoliertem Subagent |
| `agent` | Nein | Subagent-Typ bei `context: fork` (z.B. `Explore`, `Plan`) |
| `argument-hint` | Nein | Autocomplete-Hinweis, z.B. `[issue-number]` |

**Achtung**: Bindestriche in Feldnamen (`disable-model-invocation`, `user-invocable`), keine Unterstriche!

### Body (Markdown)

- Klare, schrittweise Anweisungen im Imperativ
- `$ARGUMENTS` / `$0`, `$1` für Parameter-Substitution
- `` !`command` `` für dynamische Kontext-Injection (wird vor Ausführung evaluiert)
- **Voraussetzungen-Sektion** (optional): Deklarativ Env-Variablen und Tool-Abhängigkeiten auflisten (siehe Zielstruktur unten)

### Verzeichnisstruktur

```
my-skill/
├── SKILL.md              # Hauptanweisungen (pflicht)
├── reference.md          # Detail-Doku (optional, on-demand)
├── examples.md           # Beispiele (optional)
└── scripts/              # Ausführbare Skripte (optional)
```

---

## 2. Description – Das wichtigste Feld

Die Description entscheidet, **ob und wann** Claude den Skill automatisch lädt.

**Regeln:**
- **Dritte Person** schreiben (wird in System-Prompt injiziert)
- **Trigger-Keywords** einbauen, die Nutzer tatsächlich sagen
- **Spezifisch** sein – exakt benennen was der Skill tut und wann
- **Knapp** halten – Budget: 2% Context-Window / max 16.000 Zeichen für alle Descriptions zusammen

**Gut:** `"Processes Excel files and generates reports. Use when analyzing spreadsheets or tabular data."`
**Schlecht:** `"Helps with documents"`

---

## 3. Token-Effizienz

### Progressive Disclosure
```
Startup:     Nur Name + Description geladen
Invocation:  SKILL.md Content geladen
On-demand:   reference.md, examples.md nur bei Bedarf
```

### Techniken
1. **SKILL.md unter 500 Zeilen** – Details in separate Dateien auslagern
2. **Referenzen nur eine Ebene tief** – SKILL.md verweist direkt, nicht über Zwischendateien
3. **Ausführbare Scripts** statt Claude Code generieren lassen
4. **`context: fork`** für explorative/read-only Tasks
5. **`allowed-tools`** einschränken wo sinnvoll

---

## 4. Sprache & Ton

- **Imperativ**: "Erstelle...", "Prüfe...", "Lies..."
- **Beispiele statt Erklärungen** – zeigen, nicht beschreiben
- **Keine zeitabhängigen Infos** – keine Versionsnummern die veralten
- **Konsistente Terminologie** durchgehend
- Claude ist intelligent – nicht erklären was offensichtlich ist

---

## 5. Datenbeschaffung & Schreibaktionen

Skills unterteilen ihre Schritte in **Datenbeschaffung** (read) und **Schreibaktionen** (write).

### Datenbeschaffung

Beschreibt nur **was** gebraucht wird — nicht **wie** es beschafft wird:

- **Inhalt**: Was wird gebraucht (z.B. "offene Issues des Repos")
- **Rückgabeformat**: Minimale Felder als JSON-Beispiel
  ```json
  { "number": 42, "title": "Bug in Login", "state": "open" }
  ```
- **Was weglassen**: Explizit benennen was nicht benötigt wird (z.B. "Keine Kommentare, keine Labels")
- **Keine Lese-Befehle**: Keine `curl`, `gh api`, `cat` etc. in Datenbeschaffungs-Schritten — der Main-Agent entscheidet selbst ob/wie er die Daten beschafft oder delegiert

### Schreibaktionen

Bleiben als **konkrete Befehle** (`gh`, `curl`, etc.) im Skill — hier wird explizit angegeben was ausgeführt werden soll.

### Keine Subagent-Benennung

Skills benennen keine Subagents (kein "delegiere an Explore-Agent"). Der Main-Agent entscheidet autonom ob und welcher Subagent delegiert wird.

---

## 6. Invocation-Steuerung

| Einstellung | User ruft auf? | Claude ruft auf? | Anwendungsfall |
|-------------|---------------|-----------------|----------------|
| Default | Ja | Ja | Allgemeine Skills |
| `user-invocable: false` | Nein | Ja | Hintergrundwissen |

**Hinweis**: `disable-model-invocation: true` versteckt den Skill komplett aus der Skill-Liste — auch für User-Invocation via `/`. Für Side-Effect-Skills stattdessen Bestätigungsdialoge (`AskUserQuestion`) im Skill selbst einbauen.

---

## 7. Fortgeschrittene Patterns

### Dynamische Kontext-Injection
```markdown
## PR Context
- Diff: !`gh pr diff`
- Comments: !`gh pr view --comments`
```
Commands werden **vor** Claude-Ausführung evaluiert.

### Template Pattern
Output-Format vorgeben für konsistente Antworten.

### Validation Loops
Analyse → Aktion → Validierung → Fix → Repeat

---

## 8. Shared-Dateien

Gemeinsame Patterns sind in `~/.claude/skills/.shared/` ausgelagert:

| Datei | Inhalt |
|-------|--------|
| `skill-best-practices.md` | Diese Datei — Struktur, Konventionen, Checkliste |

### Voraussetzungen-Validierung

Voraussetzungen werden deklarativ in der SKILL.md gelistet und per `requirement-checker` Skill validiert. Format:

```markdown
## Voraussetzungen
- Env: `ZAMMAD_HOST`, `ZAMMAD_TOKEN`
- Tools: `curl`, `jq`
- Projekt: `~/Develop/EDP/*`
- Datei: `~/.config/moodle-dl/token.json`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.
```

Jede Zeile beginnt mit dem Typ-Prefix (`Env`, `Tools`, `Projekt`, `Datei`). Variablen/Tools sind backtick-umschlossen, komma-getrennt. Skills ohne Voraussetzungen haben diese Sektion nicht.

Der `requirement-checker` Skill wird automatisch geladen, prüft alle Voraussetzungen direkt im Hauptkontext und meldet ERFÜLLT oder NICHT ERFÜLLT mit Anleitung zum Beheben.

### Skill-Optimierung

Jeder Skill ruft am Ende explizit `skill-optimize` auf (Einzeiler am Ende der SKILL.md). Ausnahmen: `skill-optimize` selbst und `skill-create`.

---

## 9. SKILL.md Zielstruktur

```yaml
---
name: example-skill
description: ...
disable-model-invocation: true
argument-hint: [ticket-number]
---

# Titel

Kurzbeschreibung.

## Voraussetzungen
- Env: `ZAMMAD_HOST`, `ZAMMAD_TOKEN`
- Tools: `curl`, `jq`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Schritt 1: Kern-Logik
...

## Schritt N: Letzte Schritte
...

Abschließend `skill-optimize` mit `example-skill` aufrufen.
```

**Boilerplate pro Skill:** Voraussetzungen-Sektion (deklarative Liste + 1 Zeile Verweis auf Skill) + 1 Zeile Optimize-Aufruf am Ende. Alles andere ist Kern-Logik.

---

## 10. Checkliste

- [ ] Description ist spezifisch mit Trigger-Keywords
- [ ] SKILL.md < 500 Zeilen
- [ ] Details in separate Dateien ausgelagert
- [ ] Referenzen max. eine Ebene tief
- [ ] Side-Effect-Skills haben Bestätigungsdialoge (`AskUserQuestion`)
- [ ] `allowed-tools` eingeschränkt wo sinnvoll
- [ ] Konsistente Terminologie
- [ ] Keine redundanten Erklärungen
- [ ] Frontmatter-Felder mit Bindestrichen (nicht Unterstrichen)
- [ ] Voraussetzungen deklarativ mit Typ-Prefix (`Env`, `Tools`, `Projekt`, `Datei`) + Verweis auf `requirement-checker` Skill
- [ ] Skill-Optimize-Einzeiler am Ende (außer skill-optimize und skill-create)
- [ ] Datenbeschaffung und Schreibaktionen getrennt
- [ ] Datenbeschaffungs-Schritte beschreiben Rückgabeformat (JSON-Beispiel)
- [ ] Keine Lese-Befehle in Datenbeschaffungs-Schritten

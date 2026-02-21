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

## 5. Invocation-Steuerung

| Einstellung | User ruft auf? | Claude ruft auf? | Anwendungsfall |
|-------------|---------------|-----------------|----------------|
| Default | Ja | Ja | Allgemeine Skills |
| `user-invocable: false` | Nein | Ja | Hintergrundwissen |

**Hinweis**: `disable-model-invocation: true` versteckt den Skill komplett aus der Skill-Liste — auch für User-Invocation via `/`. Für Side-Effect-Skills stattdessen Bestätigungsdialoge (`AskUserQuestion`) im Skill selbst einbauen.

---

## 6. Fortgeschrittene Patterns

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

## 7. Checkliste

- [ ] Description ist spezifisch mit Trigger-Keywords
- [ ] SKILL.md < 500 Zeilen
- [ ] Details in separate Dateien ausgelagert
- [ ] Referenzen max. eine Ebene tief
- [ ] Side-Effect-Skills haben Bestätigungsdialoge (`AskUserQuestion`)
- [ ] `allowed-tools` eingeschränkt wo sinnvoll
- [ ] Konsistente Terminologie
- [ ] Keine redundanten Erklärungen
- [ ] Frontmatter-Felder mit Bindestrichen (nicht Unterstrichen)

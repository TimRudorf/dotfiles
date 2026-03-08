# Kommunikationsweg – Referenz

Skills müssen User-Interaktionen (Rückfragen, Bestätigungen, Auswahloptionen) umgebungsabhängig umsetzen. Die Env-Variable `CLAUDE_COMM_CHANNEL` steuert den Kommunikationsweg.

## Env-Variable

| Variable | Werte | Default |
|----------|-------|---------|
| `CLAUDE_COMM_CHANNEL` | `direct`, `telegram` | `direct` |

## Verhalten je Kanal

### `direct` (Default)

Standard Claude Code Umgebung (Terminal, Desktop, SSH).

- **Rückfragen**: `AskUserQuestion` nutzen
- **Bestätigungen**: `AskUserQuestion` mit Ja/Nein-Optionen
- **Formatierung**: Markdown

### `telegram`

Claude läuft hinter einem Telegram-Bot. `AskUserQuestion` funktioniert hier **nicht**.

- **Rückfragen**: Antwortoptionen als Inline-Keyboard-Block am Ende der Nachricht anhängen (siehe FORMAT.md)
- **Bestätigungen**: Inline-Keyboard mit konkreten Optionen
- **Formatierung**: Telegram-HTML (siehe FORMAT.md)

## Pattern für Skills

Wenn ein Skill User-Interaktion braucht, prüfe `CLAUDE_COMM_CHANNEL`:

```
Wenn CLAUDE_COMM_CHANNEL = "telegram":
  → Optionen als Inline-Keyboard-Block anhängen, auf Antwort warten
Sonst (CLAUDE_COMM_CHANNEL = "direct" oder nicht gesetzt):
  → AskUserQuestion mit denselben Optionen nutzen
```

`CLAUDE_COMM_CHANNEL` ist die **einzige** Quelle — keine Fallback-Logik über andere Env-Variablen.

## Beispiel in einem Skill

```markdown
## Schritt 3: Bestätigung

Frage den User ob er fortfahren möchte.

Optionen:
- Ja, fortfahren
- Nein, abbrechen
- Anpassen

Kommunikationsweg gemäß `CLAUDE_COMM_CHANNEL` wählen (siehe `.shared/communication.md`).
```

Skills definieren nur **was** gefragt wird und **welche Optionen** es gibt. Die Wahl des Kommunikationswegs erfolgt zur Laufzeit basierend auf der Umgebung.

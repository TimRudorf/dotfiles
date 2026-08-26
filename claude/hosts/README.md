# Host-spezifische Regeln und Skills

Alles unter `claude/rules/` und `claude/skills/` gilt auf **jedem** Host.
Was hier liegt, gilt nur auf **einem** — ist aber trotzdem versioniert.

| Host | `JARVIS_HOST` | Verzeichnis |
|---|---|---|
| MacBook | `mac` | `hosts/mac/` |
| jarvis-Container | `container` | `hosts/container/` |
| Arch-Desktop Poseidon | `poseidon` | `hosts/poseidon/` |

## Wie es wirksam wird

`~/.claude/rules/` ist ein **echtes Verzeichnis** mit zwei Symlinks darin.
Claude Code findet `.md`-Dateien darunter rekursiv und löst Symlinks auf:

```bash
mkdir -p ~/.claude/rules
ln -sfn ~/dotfiles/claude/rules            ~/.claude/rules/shared
ln -sfn ~/dotfiles/claude/hosts/$JARVIS_HOST/rules ~/.claude/rules/host
```

## Was hierher gehört

Nur was auf den anderen Hosts **falsch** wäre — nicht bloß unbenutzt:
Pfade, die es woanders nicht gibt, Werkzeuge, die nur hier installiert sind,
Zugangswege, die nur von hier funktionieren.

Eine Regel, die anderswo nur *nicht greift*, gehört nach `claude/rules/`.

## Was NICHT geteilt werden soll

`~/.claude/rules/local/` ist ein echtes Verzeichnis außerhalb des Repos.
Was dort liegt, verlässt die Maschine nie. Für alles, was nicht einmal
versioniert werden soll.

## Wissen gehört nicht hierher

Wissensnotizen bleiben im Vault und damit auf allen Hosts. Was dort
host-abhängig ist, ist fast immer ein Pfad — der gehört als Klammerzusatz in
die geteilte Notiz, nicht in zwei auseinanderlaufende Fassungen.

<!-- Ergänzungen zu CLAUDE.md, die NUR im jarvis-Container gelten.
     Keine paths:-Angabe -> wird wie CLAUDE.md bei jeder Sitzung geladen. -->

# Host: container — Allgemeines

## Container-Umgebung — wo Daten persistent sind

Du lebst in einem Debian-Container (`jarvis-workspace`). Wenn das Image neu gebaut wird (z.B. nach Änderung am `Dockerfile`), verschwindet alles außer den bind-mounted Volumes. Wissen darüber, was persistent ist, vor jedem "Ich leg das mal ab"-Moment:

| Pfad im Container | Persistent? | Wofür |
|---|---|---|
| `/home/claude/` | **ja** (bind mount) | Claude-Code-State, OAuth, `~/.claude/` Skills/Agents/Memory, `~/.claude.json`, Shell-History |
| `/home/claude/.ssh/` | **ja** (eigener Mount) | SSH-Keys für Git-Zugriff |
| `/workspace/` | **ja** (bind mount) | Git-Checkouts, User-Dateien, alles was du erzeugst und später wieder brauchst |
| `/tmp/`, `/var/tmp/` | **nein** | Scratch-Files — weg nach Container-Neustart |
| `/usr/`, `/etc/`, `/opt/` (außer `/workspace`), `/root/` | **nein** | Systemverzeichnisse — weg nach Image-Rebuild |

**Praktische Folgen:**

- **User-Scoped Tools** (`pipx install`, `npm i -g` als non-root mit `$HOME/.local`, `uv tool install`) landen unter `~/.local/` → persistent über Restarts, aber nicht immer vorgesehen. Prüfe im Zweifel wo's hin installiert wurde.
- **System-Weite Installs** (`sudo apt install`) landen unter `/usr/` → **weg beim nächsten Image-Rebuild**. Das ist der Moment für den "gehört ins Dockerfile"-Ping an Tim (siehe Abschnitt *Fehlende Tools*).
- **Arbeitsergebnisse** (generierte Files, Berichte, Snapshots, PDFs): unter `/workspace/` ablegen, nicht unter `/tmp`.
- **Session-Daten** unter `/home/claude/.claude/` (ephemer, eigene Sessions/Cache des Claude-Code-Prozesses). **Persistente Wissensbasis** ist ausschließlich das Vault (Git-Repo `TimRudorf/jarvis-wiki`, im Container unter `/workspace/wiki/`).

Wenn du dir nicht sicher bist ob etwas persistent ist: lieber einmal mit `realpath`/`readlink` oder `mount | grep <pfad>` prüfen als es im Zweifel zu verlieren.

## Fehlende Tools im Container

Merkst du dass dir ein Tool in der Container-Umgebung fehlt (CLI, Paket, Library), **keinen umständlichen Umweg** bauen. Stattdessen:

1. **Selbst installieren versuchen** — `apt install`, `npm i -g`, `pipx install`, `uv tool install`, passend zum Tool-Typ.
2. Klappt das nicht (Rechte, Paket nicht verfügbar, transient): **Tim konkret fragen**, ob es dauerhaft ins `workspace/Dockerfile` soll. Nicht drumherum-hacken.
3. Nur wenn beides nicht geht: Workaround — aber markiert als Workaround mit Begründung im Code-Kommentar.

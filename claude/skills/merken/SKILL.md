---
name: merken
description: Session-Abschluss-Befehl. Reflektiert die laufende Session und schreibt alle merkenswerten Erkenntnisse (Feedback-Regeln, Profil-Fakten, Projekt-Stände, Referenzen) autonom ins jarvis-wiki-Vault, bevor die Session geschlossen wird. Trigger ausschließlich per /merken am Ende einer erfolgreichen Session.
disable-model-invocation: true
argument-hint: "[optional: konkreter Hinweis was gemerkt werden soll]"
---

# /merken — Session-Abschluss ins Vault

Wird **am Ende einer Session** aufgerufen. Aufgabe: die Session durchgehen, alles Merkenswerte ins Vault schreiben, kurzen Report geben. Default-Verhalten ist **autonom + Report** — selbst extrahieren und schreiben, kein Vorab-Approval (Vault = Tims eigenes System).

Falls `$ARGUMENTS` einen Hinweis enthält (z.B. "/merken den Encoding-Fix"), diesen als **Fokus** nehmen, aber trotzdem den Rest der Session auf weitere Merk-Kandidaten scannen.

## Schritt 1: Vault-Pfad bestimmen

Host-abhängig — prüfen welcher existiert, als `$VAULT` für den Rest merken:
- Container: `/workspace/wiki/`
- Mac: `/Users/timrudorf/Documents/jarvis-wiki/`

## Schritt 2: Session auf Merk-Kandidaten scannen

Die gesamte laufende Session durchdenken. Kandidaten sind Dinge, die **in zukünftigen Sessions** relevant sind — nicht ephemere Konversations-Details. Pro Kandidat den Typ bestimmen (siehe `$VAULT/SCHEMA.md`):

| Typ | Was | Ziel-Ordner |
|---|---|---|
| **feedback** | Verhaltensregel, Korrektur, bestätigte Präferenz ("mach nicht X", "lieber Y") | `tim/feedback/` |
| **profil** | Fakt über Tim, Eckdaten, Routine, Präferenz | `tim/` |
| **projekt** | Stand/Entscheidung/Logbuch eines laufenden Vorhabens | `projekte/` |
| **referenz** | Pointer auf externes System: URL, Pfad, Credential-Ort, Infra | `referenz/` |

**Was NICHT ins Vault** (siehe SCHEMA "Was NICHT ins Wiki gehört"): Code-Snippets (→ Repos), Secrets/Tokens, ephemere Details, Git-Historie. Im Zweifel: lieber knapp halten als zumüllen.

Wenn die Session **nichts Merkenswertes** ergab: das ehrlich sagen, nichts schreiben, fertig. Kein Pflicht-Eintrag.

## Schritt 3: Duplikate vermeiden — INDEX.md scannen

Vor jedem Write `$VAULT/INDEX.md` durchgehen: Gibt es zu diesem Kandidaten **schon eine Note**? Wenn ja → **bestehende Note updaten** (ergänzen, `updated:` setzen), nicht neu anlegen. Nur wenn nichts passt → neue Note.

## Schritt 4: Schreiben (gemäß SCHEMA.md)

Pro Kandidat:
- Note unter dem Ziel-Ordner als Kebab-Case-File mit korrektem **Frontmatter** (`title`, `type`, `tags` (1–4), `description`, `created`, `updated`; bei `projekt` zusätzlich `status`).
- Bei **feedback**/**projekt**: Why- und How-to-apply-**Callouts** (`> [!info] Why` / `> [!tip] How to apply`).
- Mindestens **1 Backlink** (`[[pfad/datei]]`) setzen, sonst Verwaisung.
- **INDEX.md** in der passenden Sektion ergänzen (Ein-Zeilen-Hook).
- **LOG.md**: `## [DATUM] light | <titel>` (Datum aus `date`/currentDate).

### Sonderfall feedback-Klassifizierung

Für jede **feedback**-Note klassifizieren (SCHEMA "Wenn Tim Feedback gibt"):
- **Kontextspezifisch** (nur eine Domain) → nur INDEX.md unter Domain-Sektion. **Autonom.**
- **Universell** (greift in jeder Session — Stil, Arbeitsphilosophie, Approval-Verhalten) → One-Liner in `~/.claude/CLAUDE.md` Block "Universelle Verhaltensregeln" **+** INDEX.md unter "Universelle Regeln". **Der CLAUDE.md-Edit braucht Approval** (Dotfiles-Push):
  - Bridge-Runtime (`mcp__bridge__*` vorhanden) → `mcp__bridge__request_approval`.
  - Sonst → `AskUserQuestion`.
  - Die Vault-Note selbst trotzdem sofort autonom schreiben; nur der CLAUDE.md-Touch wartet auf Freigabe.

Im Zweifel feedback als **universell** behandeln und fragen.

## Schritt 5: Sync

Vault-Writes werden via PostToolUse-Hook **automatisch committet+gepusht** — nicht manuell `git commit` im Vault aufrufen. Bei einem CLAUDE.md-Edit (dotfiles) gilt `private-repos-auto-roundtrip` (Branch → Commit → Push → PR → Merge).

## Schritt 6: Report + Abschluss

Kurzer Report an Tim — pro gemerkter Note eine Zeile:

```
🧠 Gemerkt:
- tim/feedback/<slug> — <hook>  [universell, CLAUDE.md-Edit pending Approval]
- projekte/<x>/log — <hook>
(INDEX + LOG aktualisiert, Vault gepusht)
```

War nichts zu merken: das sagen.

**Topic schließen** (nur Bridge-Runtime): Wenn Tim "Session schließen" signalisiert hat und die Arbeit erkennbar durch ist, als letzten Schritt `mcp__bridge__close_topic(topic_id)`. Auf dem Mac/Desktop ohne Bridge entfällt das.

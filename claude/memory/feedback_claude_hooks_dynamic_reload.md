---
name: Claude Code laedt Hooks dynamisch — kein Session-Restart nach settings.json-Aenderung noetig
description: Hook-Konfiguration in settings.json wird per Tool-Call frisch ausgewertet, nicht beim Session-Start gesnapshottet
type: feedback
---
Wenn `~/.claude/settings.json` waehrend einer laufenden Session um neue Hooks ergaenzt wird (z.B. PostToolUse-Hook), sind die Hooks **sofort aktiv** — sobald der naechste Tool-Call kommt, ruft Claude Code den neu konfigurierten Hook auf.

**Why:** Live verifiziert am 2026-04-26: PostToolUse-Auto-Sync-Hook in settings.json gepushed, in derselben Session danach einen Memory-Edit gemacht — der Hook hat sofort ausgeloest und committed+pushed, obwohl die Session vor dem settings.json-Update gestartet wurde. Vorherige Annahme "Settings werden beim Start gesnapshottet" war falsch.

**How to apply:**
- Nach Aenderungen an `hooks.*` in settings.json: kein Session-Restart noetig fuer Tim erzwingen.
- Trotzdem ehrlich kommunizieren: *"Hook ist live — falls etwas nicht klappt, doch neue Session starten"*, weil andere Settings-Bloecke (`env`, `enabledPlugins`) durchaus erst beim Start gelesen werden duerften (nicht verifiziert).
- Bei Hook-Tests in laufender Session funktional: vom Hook erzeugte Side-Effects (commit/push) finden statt, aber das Hook-Output (additionalContext, decision-Block) wirkt erst ab dem naechsten Trigger.

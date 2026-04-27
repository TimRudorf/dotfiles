---
name: Infrastruktur-Feedback-Loop
description: Beobachtungen zu fehlenden Tools / Infra-Verbesserungen in /workspace/infrastructure-feedback.md sammeln; Schedule berichtet alle 3 Tage
type: feedback
originSessionId: b281a2a2-c7d5-4532-a743-7d416360dc32
---
Wenn mir während der Arbeit etwas auffällt, das unsere Infrastruktur, das Tooling, den Container, die Bridge oder den Workflow generell besser machen könnte → **direkt** in `/workspace/infrastructure-feedback.md` unter "Offen" eintragen (Datum, Beobachtung, Empfehlung, Aufwand/Impact).

**Why:** Tim ist explizit empfänglich für Verbesserungsvorschläge und will, dass wir uns kontinuierlich gemeinsam verbessern. Er möchte aber nicht in jedem Chat damit gestört werden, sondern alle ~3 Tage gesammelt drüberschauen. Ein persistentes File + Schedule entkoppelt das Sammeln vom Reporting.

**How to apply:**
- Trigger: fehlendes Tool, hakelige Workflows, wiederkehrende Reibung, sinnvolle Automation, Sicherheits-/Bequemlichkeits-Findings
- Eintragen sofort, nicht aufschieben — bei der Arbeit, wenn's frisch ist
- Bei akuten/blocking Tools: weiterhin direkt fragen (siehe CLAUDE.md "Fehlende Tools im Container") — das File ist für Nice-to-haves und Strukturelles
- Schedule "Infra-Feedback Review" (cron `0 9 */3 * *`) liest das File, fasst zusammen, gibt beratende Empfehlung; checkt im selben Zug `claude --version` gegen `npm view @anthropic-ai/claude-code version`
- Nach Tims Entscheidung: erledigte Items in den "Erledigt"-Block verschieben, nicht löschen (Historie)

---
name: openclaw als Jarvis-Vorbild
description: openclaw-Repo dient als Ideengeber für neue Jarvis-Features — bei neuen Features dort reinschauen
type: reference
originSessionId: cbd92e98-dddc-4e6e-99bd-eabdf2cb30ad
---
Tims Jarvis-Setup (`jarvis-workspace` + `jarvis-bridge`, ehemals claude-work) orientiert sich konzeptionell an **openclaw** (https://github.com/openclaw/openclaw), einem deutlich größeren selbst-gehosteten Multi-Channel-Assistant-Framework.

**Wann relevant:** Wenn ein neues Feature für Jarvis geplant wird (z.B. Heartbeats, Skill-Registry, Sandbox-Modell, Per-Channel-Routing, Scheduling-UI, Voice-Stack, Canvas), vorher kurz in openclaw nachschauen:
- Gibt es das Feature dort schon?
- Wie lösen sie es (Datei-Pfade, Architektur)?
- Was lässt sich 1:1 übernehmen, was wäre Over-Engineering für Jarvis' schlankes Setup?

**How to apply:** Nicht die openclaw-Terminologie übernehmen (Tim verwendet bewusst andere Namen — `PERSONA.md` / `PROFILE.md` statt `SOUL.md` / `IDENTITY.md`, um nicht wie ein openclaw-Klon zu wirken). Konzept klauen, Benennung eigen halten.

**Querverweise:**
- openclaw-Nennung im Jarvis-README unter "Inspiration"
- Bekannte openclaw-Dateien von Interesse: `docs/concepts/soul.md`, `docs/concepts/system-prompt.md`, `src/agents/bootstrap-files.ts`, `src/agents/heartbeat-system-prompt.ts`, `src/agents/bootstrap-hooks.ts`

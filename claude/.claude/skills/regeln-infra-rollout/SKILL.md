---
name: regeln-infra-rollout
description: Tims Regeln für Infrastruktur, Vorlagen und Rollouts über mehrere Repos: einmal generisch für alle Ökosysteme bauen statt je Sprache, Vorlagen tragen nur das Minimum, vorhandene Dopplungen vorher auflösen. Nutzen bei Scaffolds, Workflow-Vorlagen und allem, was in viele Repos kopiert wird.
---

# Infra Rollout — Tims Regeln

Diese Regeln galten bis 2026-08-26 als "universell" und lagen in `CLAUDE.md`.
Sie greifen aber nur in diesem Zusammenhang — deshalb stehen sie hier und
kosten nichts, solange der Zusammenhang nicht vorliegt.

## generisch-ueber-oekosysteme

Infrastruktur/Werkzeuge **einmal generisch** für alle Ökosysteme bauen (Go, Delphi, Frontend, sonstige), nicht je Sprache; vorhandene Dopplungen **vorher** auflösen statt danebenbauen. Besonders scharf vor einem Rollout: was in jedes Repo kopiert wird, ist ein Multiplikator. Im Repo-PR gilt **erst löschen, dann einspielen**. Zwei Workflows/Jobs mit demselben `name:` teilen sich die Concurrency-Gruppe und brechen einander ab. Volltext: `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/generisch-ueber-oekosysteme.md` (Archiv)

## vorlage-traegt-nur-das-minimum

Vorlagen/Scaffolds tragen nur das Minimum. Prüfung je Element: „braucht das **jede** Ableitung?" — nein → raus, **auch wenn nützlich**; unklar → Reviewer fragen. **Bestand ist kein Vorbild** (verbreitet ≠ gebraucht). Vertrag zum Zielsystem + erklärende Kommentare/`TODO`-Marker bleiben — schmal ≠ leer. Volltext: `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/vorlage-traegt-nur-das-minimum.md` (Archiv)

---

Was hier steht, ist die **geltende Fassung**. Die ausführlichen Begründungen
von früher liegen im Archiv unter `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/` — dort nachlesen,
wenn ein Grenzfall unklar bleibt, aber im Zweifel gilt dieser Text.

---
name: regeln-pr-workflow
description: Tims Regeln rund um Pull Requests: wann ein PR fertig ist, Review vor dem Merge, Umgang mit fremden PRs, CI nach dem Push, automatisches Schließen verlinkter Issues. Nutzen, sobald ein PR erstellt, geprüft, gemerged oder bewertet wird — auch bei 'ist der PR fertig?', 'kann das gemerged werden?', 'CI ist rot'.
---

# Pr Workflow — Tims Regeln

Diese Regeln galten bis 2026-08-26 als "universell" und lagen in `CLAUDE.md`.
Sie greifen aber nur in diesem Zusammenhang — deshalb stehen sie hier und
kosten nichts, solange der Zusammenhang nicht vorliegt.

## ci-nach-push-beobachten

nach jedem Push CI-Run-Status abwarten, bei Fail Logs ziehen + fixen

## vor-merge-reviews-pruefen

vor **jedem** PR-Merge offene Reviews prüfen + Threads abarbeiten (umsetzen oder begründet auflösen), erst dann mergen; `BLOCKED` bei grüner CI = unaufgelöste Threads; nach Push ggf. erneut prüfen. Gilt für alle Repos. Volltext: `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/vor-merge-reviews-pruefen.md` (Archiv)

## pr-review-lokaler-agent

**kein Copilot-Review** mehr anfordern oder abarbeiten (Bot auf der GHE-Instanz inaktiv, `--add-reviewer` ist ein stiller No-op). Stattdessen vor dem Merge einen **skeptischen lokalen Review-Agent** auf den Diff ansetzen (`/edp-review`): Auftrag konkret halten (Ressourcenpfade, Rechte, Grenzfälle, Encoding), **jeder Fund braucht ein konkretes Fehlerszenario**, Funde selbst verifizieren statt blind umsetzen. Ersetzt Copilot, **nicht** das menschliche Review (`todo:review` bleibt). Volltext: `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/pr-review-lokaler-agent.md` (Archiv)

## pr-fertig-erst-wenn-mergebar

ein PR ist erst fertig, wenn er **theoretisch mergebar** ist (`mergeStateStatus CLEAN`/`mergeable MERGEABLE`). Code geschrieben + CI grün ≠ fertig. Bei `BLOCKED`/`BEHIND`/`DIRTY`/rotem Check: Ursache bestimmen (BLOCKED bei grüner CI = meist unaufgelöste Conversations/fehlende Approval) → fixen → im Loop neu prüfen bis merge-ready. Den eigentlichen Merge ggf. dem Reviewer überlassen, aber den merge-ready-Zustand selbst herstellen. Volltext: `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/pr-fertig-erst-wenn-mergebar.md` (Archiv)

## fremde-prs-sind-kein-blocker

ein offener PR eines Kollegen auf derselben Datei hält den eigenen Fix **nicht** auf: der Fix geht rein, Rebase und Konfliktauflösung liegen beim Autor des anderen PRs. Repos nie nach fremder PR-Aktivität aus einer Welle oder einem Sammel-Vorgang herausfiltern — Dateiüberschneidung nur als **Konflikt-Prognose** für die Reihenfolge erheben. Fremde PRs weiterhin nicht anfassen, nicht nachfassen, nicht mergen — aber auch **nicht auf sie warten**; der eigene Vorgang ist fertig, wenn die eigene Arbeit erledigt ist. Kein Freibrief, in einen fremden Branch hineinzuarbeiten, und andere Gates (Secret-Block, offene Tim-Entscheidung) bleiben echte Blocker. Volltext: `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/fremde-prs-sind-kein-blocker.md` (Archiv)

## pr-issues-auto-schliessen

im PR-Body `Closes/Fixes #NN` setzen (eine Zeile pro Issue), das ein PR vollständig erledigt → Issue schließt beim Merge in den **Default-Branch** automatisch (bei `schn_feuersoftware` = `dev`, dort greift's schon beim Feature→dev-Merge). Nur teilweise/verwandte Bezüge als `Ref #NN`. Nach **jedem** Merge verifizieren, dass die Ziel-Issues wirklich zu sind; `Ref`-verlinkte oder unverlinkte manuell schließen (mit Abschluss-Kommentar), Restpunkte ggf. als eigenes Issue auskoppeln. Volltext: `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/pr-issues-auto-schliessen.md` (Archiv)

## code-self-check-vor-review

vor jeder Tim-Review eines Code-Diffs selbst per `edp-design-loop`-Pattern (Deploy → Browser-Verify via playwright-cli → Screenshot) durchlaufen, bei Fehlern iterieren, bis das Ergebnis passt. CI-grün ≠ UI-funktioniert. Tim nicht selbst smoke-testen lassen, was ich automatisieren kann. Volltext: `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/code-self-check-vor-review.md` (Archiv)

---

Was hier steht, ist die **geltende Fassung**. Die ausführlichen Begründungen
von früher liegen im Archiv unter `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/` — dort nachlesen,
wenn ein Grenzfall unklar bleibt, aber im Zweifel gilt dieser Text.

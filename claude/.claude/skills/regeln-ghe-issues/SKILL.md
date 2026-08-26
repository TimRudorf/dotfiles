---
name: regeln-ghe-issues
description: Tims Regeln für GitHub-Enterprise-Issues: jedes Issue bekommt einen Type, Fix-Branch und Cascade direkt festhalten, Sammel-Issues nach der Auslagerung schließen, einen Sammelvorgang nicht wegen eines blockierten Repos offenhalten. Nutzen beim Anlegen, Bearbeiten oder Schließen von GHE-Issues.
---

# Ghe Issues — Tims Regeln

Diese Regeln galten bis 2026-08-26 als "universell" und lagen in `CLAUDE.md`.
Sie greifen aber nur in diesem Zusammenhang — deshalb stehen sie hier und
kosten nichts, solange der Zusammenhang nicht vorliegt.

## issue-fix-branch-cascade-festhalten

beim Erstellen von GHE-Issues direkt den Fix-Branch (niedrigste betroffene Ebene, Fall A–D der Branch-Cascade) + den Cascade-Pfad bestimmen und als Sektion **„## Branch & Cascade"** + Test-Akzeptanzkriterium ins Issue schreiben, damit Bearbeiter es direkt anwenden können. Volltext: `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/issue-fix-branch-cascade-festhalten.md` (Archiv)

## issue-type-immer-setzen

**jedes neu angelegte Issue bekommt einen Type** (`gh issue create --type "<Type>"`), auch Randfunde, Auskopplungen, Notizen. „Kein Type passt" gibt es nicht — dafür ist `Sonstiges` da; nicht reflexhaft `Task` nehmen, die spezifischen Types (`Refactoring`/`Tests`/`CI/Workflows`/`Documentation`/`Security-Issue`) tragen die Information. Types **live abfragen** statt raten (Org `edp`: 13). Vergessen → `gh issue edit <nr> --type` nachziehen. Type ≠ Label, beides setzen wo beides passt. ⚠️ Types sind ein **Org**-Feature — in Tims persönlichen `TimRudorf/*`-Repos gibt es keine. Volltext: `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/issue-type-immer-setzen.md` (Archiv)

## sammel-issue-nach-auslagerung-schliessen

**ein Sammel-Issue ist ein Transportmittel, kein Ablageort.** Anlegen ist erlaubt; sobald seine Punkte als eigene Issues im jeweiligen Repo stehen, wird es **geschlossen** — Abschlusskommentar, der **jede** Auskopplung als `<org>/<repo>#NN` benennt, `gh issue close --reason completed`. Kein offenes Sammel-Issue als Übersicht: doppelte Buchführung, und der Bestand liest sich als „da ist noch Arbeit". Teil-Auslagerung ist **kein** Grund zum Offenhalten → Restpunkte ebenfalls auslagern (notfalls Type `Note`). Einzel-Issues tragen `Ref <sammelrepo>#NN`. Alte offene Sammel-Issues beim Draufstoßen nachtragen und schließen. Sonderfall blockierte Repos: `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/sammelvorgang-nicht-wegen-einzelrepo-offenhalten.md` (Archiv). Volltext: `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/sammel-issue-nach-auslagerung-schliessen.md` (Archiv)

## sammelvorgang-nicht-wegen-einzelrepo-offenhalten

ein Sammel-/Fanout-Vorgang bleibt **nicht offen, weil einzelne Ziel-Repos blockiert sind**. Prüffrage: *bekommen wir das Repo mit eigener Arbeit durch?* Ja → kein Blocker, dann wird gearbeitet. Nein (fehlende Bereitstellung auf dem Runner, Lizenz, Runner-Defekt) → **auskoppeln**: eigenes Issue im betroffenen Repo mit Ursache + Beleg (Fehlermeldung/CI-Lauf), `Ref <org>/<sammelrepo>#NN` je hängendem Vorgang und was zu tun wäre, Assignee `tim-rudorf` — vorher auf Dubletten prüfen. Danach den Sammel-Vorgang mit Abschlusskommentar schließen, der die Auskopplungen benennt. Greift **nur**, wenn die Restmenge ausschließlich aus blockierten Repos besteht — kein Freibrief zum vorzeitigen Schließen. Volltext: `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/sammelvorgang-nicht-wegen-einzelrepo-offenhalten.md` (Archiv)

---

Was hier steht, ist die **geltende Fassung**. Die ausführlichen Begründungen
von früher liegen im Archiv unter `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/` — dort nachlesen,
wenn ein Grenzfall unklar bleibt, aber im Zweifel gilt dieser Text.

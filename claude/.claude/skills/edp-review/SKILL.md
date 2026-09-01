---
name: edp-review
description: "Skeptisches lokales Code-Review eines Pull Requests oder eines Diffs durch einen Sub-Agent — Ersatz für den früheren Copilot-Review. Nutzen, wenn ein PR vor dem Merge geprüft werden soll oder der User „review den PR\", „schau dir den Diff kritisch an\", „/edp-review\" sagt. Findet Fehler, verifiziert sie und behebt die berechtigten."
argument-hint: "[pr-nummer oder branch]"
allowed-tools: Bash, Read, Edit, Write, Agent
---

# PR skeptisch lokal reviewen

Ersetzt den früheren Copilot-Review vollständig.

> **Copilot wird nicht mehr angefordert.** Kein `--add-reviewer copilot-pull-request-reviewer` (stiller No-op), keine GraphQL-`requestReviews`-Anforderung, kein Warten auf Bot-Threads. Der Bot ist auf der GHE-Instanz inaktiv.

## Voraussetzungen
- Tools: `gh`, `git`

Voraussetzungen gemäß `requirement-checker` Skill validieren.

## Schritt 1: Diff bestimmen

Aus `$ARGUMENTS` ableiten:
- **PR-Nummer** → `gh pr view <nr> -R einsatzleitsoftware.ghe.com/edp/<repo> --json headRefName,baseRefName`, dann lokal `git diff origin/<base>...<head>`
- **Kein Argument** → aktueller Branch gegen seinen Ziel-Branch (i.d.R. `dev`)

Repo aus der Remote-URL ableiten. Arbeitsverzeichnis ist das lokale Checkout bzw. der Worktree.

## Schritt 2: Skeptischen Review-Agent beauftragen

Einen Sub-Agent starten. Der Auftrag muss **konkret** sein — ein generisches „review das" liefert Geschwafel.

**Pflichtbestandteile des Auftrags:**

1. **Haltung:** „Du bist ein skeptischer Reviewer. Finde echte Fehler. Geh davon aus, dass der Autor etwas übersehen hat, und versuche aktiv es zu widerlegen. Nicht loben, nicht paraphrasieren."
2. **Beweislast:** Jeder Fund braucht ein **konkretes Fehlerszenario** (Eingabe → falsches Verhalten). Ohne plausibles Szenario ist es kein Fund. Unsicheres ausdrücklich als „unsicher" kennzeichnen. „Lieber drei belastbare Funde als zehn vage."
3. **Arbeitsverzeichnis + Diff-Kommando** wörtlich mitgeben.
4. **Encoding-Falle:** `.pas`/`.dfm` sind Windows-1252 → `grep` immer mit `-a`, Lesen via `iconv -f WINDOWS-1252 -t UTF-8`. Ohne diesen Hinweis hält der Agent leere Trefferlisten für Abwesenheit.
5. **Risikostellen benennen** — die Punkte, an denen dieser konkrete Diff schiefgehen kann. Typische Achsen:
   - **Ressourcen/Speicher** (Delphi): wird jedes Objekt auf **jedem** Pfad genau einmal freigegeben? Was bei Exception? Bei Indy: `AResponseInfo.ContentStream` gibt Indy **selbst** frei → doppeltes Free = Absturz, fehlendes = Leck.
   - **Sicherheit/Rechte:** Eingaben validiert **vor** allen Verwendungen? Neuer Handler-Zweig mit denselben Prüfungen wie die Nachbarn?
   - **Grenzfälle** der neuen Logik + ob die Tests das **tatsächliche** Verhalten abgleichen oder nur das erhoffte.
   - **Registrierung:** neue Delphi-Units in `.dpr` **und** `.dproj` — Haupt- und Testprojekt.
   - **Encoding:** Windows-1252, kein BOM, kein U+FFFD.
   - **Frontend:** Konsistenz mit bestehenden Listenern/Konventionen; entfernte Trigger nirgends sonst benutzt.
6. **Regelkonformität** gegen `~/.claude/rules/` (`shared/`, `host/`, `local/`). Der Agent hat diese Regeln **nicht** im Kontext: `paths`-gebundene Regeln laden nur, wenn eine passende Datei über Read/Edit/Write angefasst wird — ein Sub-Agent, der mit `cat`/`grep` liest, löst das nie aus. Deshalb wörtlich in den Auftrag:
   - **Anwendbare Regeln selbst bestimmen und im Volltext lesen**, nicht nach Titel raten:
     ```bash
     for f in ~/.claude/rules/*/*.md; do echo "== $f"; sed -n '1,15p' "$f"; done
     ```
     Kein `---` in Zeile 1 → die Regel gilt immer. Mit `paths:` → nur, wenn ein Glob auf eine geänderte Datei passt.
   - Prüfen ist **Textvergleich**: je Verstoß **Regeldatei + Abschnitt**, `Datei:Zeile` und Soll/Ist. Das ist der Beleg — ein Fehlerszenario (Punkt 2) braucht ein Regelverstoß nicht.
   - Nur, was der Diff **einbringt oder anfasst**. Altlast im Umfeld getrennt auflisten (RULES.md → „Erkannte Regelverstöße": Behebung anbieten, nicht ungefragt mitfixen).
   - Nicht nur Code: **PR-Titel, PR-Body und Commit-Botschaften** fallen unter `texte.md` (Wesentliches zuerst, bearbeiten statt anhängen, echte Umlaute) und unter die Unsichtbarkeits-Regel — kein Hinweis auf AI.
7. **Ausgabeformat:** nach Schwere sortiert, je Fund `Datei:Zeile` + Fehler + Szenario + Behebungsvorschlag. **Regelverstöße als eigener Block**, damit sie nicht zwischen den Bugs untergehen. Geprüft-und-in-Ordnung ans Ende, eine Zeile pro Punkt, ohne Lob.

## Schritt 3: Funde verifizieren

**Nicht ungeprüft übernehmen**. Jeden Fund selbst am Code nachvollziehen:

- **Berechtigt** → fixen, Tests ergänzen wo sinnvoll, committen.
- **Fehlalarm** → verwerfen und im Report kurz begründen, warum er keiner ist.
- **Regelverstoß** → die zitierte Regelstelle selbst nachlesen, bevor gefixt wird. Der Agent zitiert aus einer Datei, die sonst niemand in dieser Sitzung gesehen hat; eine falsch verstandene Regel erzeugt einen Fix, den die Regel gar nicht verlangt.

Bei Unsicherheit den Agent per Nachfrage weiterarbeiten lassen, statt zu raten.

## Schritt 4: Ergebnis festhalten

Kurze Notiz an den PR: **was geprüft** wurde, **was gefunden**, **was behoben**, **was verworfen und warum**. Das ist die Andockstelle für das menschliche Review.

Label `todo:review` **bleibt** — der Agent ersetzt Copilot, nicht den Menschen.

Nach einem Fix-Push: CI erneut abwarten und den PR bis `mergeStateStatus CLEAN` treiben.

## Regeln

- Kein Hinweis auf AI in PR-Kommentaren. Deutsch mit echten Umlauten.
- Der Merge selbst bleibt beim Reviewer/Team, sofern nicht anders gesagt.

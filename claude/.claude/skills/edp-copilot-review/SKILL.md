---
name: edp-copilot-review
description: This skill should be used when the user asks to "review Copilot feedback", "process Copilot review", "handle Copilot suggestions", or uses /edp-copilot-review. It fetches Copilot's PR review, lets the user decide what to implement, creates an implementation plan, then comments on resolved/skipped items and resolves all threads.
argument-hint: [pr-number]
---

# Copilot Review verarbeiten

Holt das Copilot-Review eines PRs, lässt den User entscheiden was umgesetzt wird, erstellt einen Umsetzungsplan, kommentiert die Ergebnisse und resolved alle Threads.

## Schritt 1: PR identifizieren

Falls `$ARGUMENTS` eine PR-Nummer enthält → direkt verwenden.

Falls kein Argument: Aktuelle Branch und offene PRs prüfen:

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh pr list --author @me --state open --limit 5
```

Falls genau ein PR → diesen verwenden. Falls mehrere → per `AskUserQuestion` auswählen lassen. Falls keiner → User informieren und abbrechen.

## Schritt 2: Kontext ermitteln (parallel)

**Repo-Info**:
```bash
GH_HOST=einsatzleitsoftware.ghe.com git remote get-url origin
```
Repo-Name extrahieren (z.B. `edp/edpweb` → owner: `edp`, repo: `edpweb`).

**PR-Details** (MCP):
```tool
mcp__github__pull_request_read(method: "get", owner: <owner>, repo: <repo>, pullNumber: <nr>)
```

**Review-Kommentare** (MCP):
```tool
mcp__github__pull_request_read(method: "get_review_comments", owner: <owner>, repo: <repo>, pullNumber: <nr>)
```

**Reviews** (MCP):
```tool
mcp__github__pull_request_read(method: "get_reviews", owner: <owner>, repo: <repo>, pullNumber: <nr>)
```

Aus den Reviews das **Copilot-Review** identifizieren (Autor enthält `copilot` oder `bot`).

Falls kein Copilot-Review vorhanden → User informieren und abbrechen.

## Schritt 3: Review-Kommentare aufbereiten

Alle Review-Threads aus dem Copilot-Review sammeln und strukturiert anzeigen:

```
Copilot Review für PR #<nr>: <titel>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. [<datei>:<zeile>] <zusammenfassung des Kommentars>
   → <kurzes Zitat oder Kernaussage>

2. [<datei>:<zeile>] <zusammenfassung des Kommentars>
   → <kurzes Zitat oder Kernaussage>

...
```

## Schritt 4: User-Entscheidung einholen

Per `AskUserQuestion` (multiSelect) fragen:

> Welche Copilot-Vorschläge sollen umgesetzt werden?

Optionen: Jeden Vorschlag als Option mit Label `#<nr>: <kurzbeschreibung>` und Description mit dem Kommentar-Inhalt.

**Hinweis**: Bei mehr als 4 Vorschlägen die Auswahl in Gruppen aufteilen (max 4 Optionen pro Frage) oder alternativ eine nummerierte Liste anzeigen und den User per Freitext die Nummern eingeben lassen.

## Schritt 5: Umsetzungsplan erstellen

Für jeden akzeptierten Vorschlag:

1. Die betroffene Datei lesen
2. Den Copilot-Vorschlag analysieren
3. Konkrete Änderungen planen

Den Plan dem User als Übersicht präsentieren:

```
Umsetzungsplan
━━━━━━━━━━━━━━

✓ Vorschlag #1: <beschreibung>
  → <geplante Änderung>

✓ Vorschlag #3: <beschreibung>
  → <geplante Änderung>

✗ Vorschlag #2: <beschreibung>
  → Wird nicht umgesetzt (vom User abgelehnt)
```

Per `AskUserQuestion` bestätigen lassen: **"Umsetzen"**, **"Anpassen"**, **"Abbrechen"**

- **Umsetzen** → weiter zu Schritt 6
- **Anpassen** → User nach Änderungen fragen, Plan überarbeiten
- **Abbrechen** → Skill beenden

## Schritt 6: Änderungen implementieren

Die geplanten Änderungen mit `Read` und `Edit` umsetzen. Dabei:

- Jede Datei vor dem Editieren lesen
- Änderungen minimal und fokussiert halten
- Nach allen Änderungen eine kurze Zusammenfassung anzeigen

## Schritt 7: Review-Threads kommentieren und resolven

Für **jeden** Copilot-Review-Thread einen Kommentar hinterlassen und resolven.

**Für umgesetzte Vorschläge** — Kommentar-Text:
```
Umgesetzt: <kurze Beschreibung was geändert wurde>
```

**Für abgelehnte Vorschläge** — Kommentar-Text:
```
Nicht umgesetzt: <Begründung — z.B. "Vom Entwickler als nicht relevant eingestuft", "Widerspricht bestehender Architektur", etc.>
```

Für jeden Thread die Review-Kommentar-ID ermitteln und kommentieren. Da der GitHub MCP Server kein direktes Thread-Reply unterstützt, über `gh` CLI:

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh api repos/<owner>/<repo>/pulls/<pr>/comments/<comment_id>/replies -f body="<kommentar>"
```

Anschließend alle Threads per GraphQL resolven:

```bash
GH_HOST=einsatzleitsoftware.ghe.com gh api graphql -f query='
  mutation {
    resolveReviewThread(input: {threadId: "<thread_node_id>"}) {
      thread { isResolved }
    }
  }
'
```

**Hinweis**: Die `thread_node_id` aus den Review-Kommentaren (Feld `node_id` oder über GraphQL abfragen) verwenden.

Falls ein Thread-Resolve fehlschlägt → Fehler loggen aber fortfahren.

## Schritt 8: Zusammenfassung

Dem User eine Zusammenfassung anzeigen:

```
Copilot Review verarbeitet ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Umgesetzt:     <n> Vorschläge
Nicht umgesetzt: <m> Vorschläge
Threads resolved: <x>/<total>

Geänderte Dateien:
- <datei1>
- <datei2>
```

## Regeln

- **GitHub-Abfragen** bevorzugt über MCP-Tools (`mcp__github__*`)
- **Nur** `GH_HOST=einsatzleitsoftware.ghe.com` vor `gh`-/`git`-Befehlen setzen
- **Keine eigenmächtigen Code-Änderungen** — nur was der User in Schritt 4 bestätigt hat
- **Keine Commits** erstellen — nur lokale Dateiänderungen. Der User committet selbst.
- **Fehlertoleranz**: Einzelne fehlgeschlagene Thread-Resolves nicht als Abbruchgrund werten
- **Deutsche Sprache** in Kommentaren mit echten Umlauten
- **Kein Hinweis** auf AI oder automatische Verarbeitung in den Review-Kommentaren

---

## Skill-Optimierung

Nach Abschluss dieses Skills kurz bewerten, ob Optimierungsbedarf besteht:

- **Empfehlung "ja"**: Fehler aufgetreten, Workarounds nötig, Befehle wiederholt, User-Korrekturen
- **Empfehlung "nein"**: Reibungsloser Lauf wie dokumentiert

Per `AskUserQuestion` fragen:

> Skill abgeschlossen. Soll die Skill-Dokumentation optimiert werden?
> Empfehlung: {ja — [kurzer Grund] | nein — Lauf war reibungslos}

Optionen: **"Ja, optimieren"**, **"Nein"**

Bei "Ja": `skill-optimize` mit Skill-Name `edp-copilot-review` ausführen.

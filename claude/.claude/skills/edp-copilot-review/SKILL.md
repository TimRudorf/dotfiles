---
name: edp-copilot-review
description: This skill should be used when the user asks to "review Copilot feedback", "process Copilot review", "handle Copilot suggestions", or uses /edp-copilot-review. It fetches Copilot's PR review, lets the user decide what to implement, creates an implementation plan, then comments on resolved/skipped items and resolves all threads.
argument-hint: [pr-number]
---

# Copilot Review verarbeiten

Holt das Copilot-Review eines PRs, lässt den User entscheiden was umgesetzt wird, erstellt einen Umsetzungsplan, kommentiert die Ergebnisse und resolved alle Threads.

## Voraussetzungen
- Tools: `gh`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Schritt 1: PR identifizieren

Falls `$ARGUMENTS` eine PR-Nummer enthält → direkt verwenden.

Falls kein Argument: Aktuelle Branch und offene PRs prüfen:

```bash
gh pr list --author @me --state open --limit 5
```

Falls genau ein PR → diesen verwenden. Falls mehrere → per `AskUserQuestion` auswählen lassen. Falls keiner → User informieren und abbrechen.

## Schritt 2: Copilot-Review laden (Subagent-Delegation)

Repo-Info ermitteln:
```bash
git remote get-url origin
```
Repo-Name extrahieren (z.B. `edp/edpweb` → owner: `edp`, repo: `edpweb`).

Dann einen **Subagent** (`git-expert`) starten, der die PR-Review-Daten beschafft.

**Was wird gebraucht:**
Alle Review-Kommentare des Copilot-Reviews für PR `#<nr>` in Repo `edp/<repo>`.

**Rückgabeformat:**
```json
{
  "pr_titel": "...",
  "pr_nummer": 42,
  "kommentare": [
    {"comment_id": 123, "node_id": "PRRT_...", "datei": "src/foo.pas", "zeile": 42, "body": "Copilot-Kommentar-Text..."}
  ]
}
```
→ **Nur** Kommentare vom Copilot-Autor (Autor enthält `copilot` oder `bot`).
→ Falls kein Copilot-Review vorhanden: explizit `"kommentare": []` melden.

**Nicht benötigt im Main-Agent:** PR-Body, andere Reviews, Nicht-Copilot-Kommentare.

Falls kein Copilot-Review vorhanden → User informieren und abbrechen.

## Schritt 3: Review-Kommentare aufbereiten

Alle Review-Threads aus dem Copilot-Review übersichtlich anzeigen. Pro Kommentar: Datei + Zeile, Zusammenfassung, Kernaussage. Darstellungsformat frei wählen.

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

Den Plan dem User als Übersicht präsentieren — pro Vorschlag: Nummer, Beschreibung, geplante Änderung, und ob umgesetzt oder abgelehnt. Darstellungsformat frei wählen.

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

Für jeden Thread per `gh` CLI kommentieren:

```bash
gh api repos/<owner>/<repo>/pulls/<pr>/comments/<comment_id>/replies -f body="<kommentar>"
```

Anschließend alle Threads per GraphQL resolven:

```bash
gh api graphql -f query='
  mutation {
    resolveReviewThread(input: {threadId: "<node_id>"}) {
      thread { isResolved }
    }
  }
'
```

**Hinweis**: Die `node_id` aus den Subagent-Ergebnissen (Schritt 2) verwenden.

Falls ein Thread-Resolve fehlschlägt → Fehler loggen aber fortfahren.

## Schritt 8: Zusammenfassung

Dem User eine Zusammenfassung anzeigen: Anzahl umgesetzter/abgelehnter Vorschläge, resolved Threads, und geänderte Dateien. Darstellungsformat frei wählen.

## Regeln

- **GitHub-Leseabfragen** über Subagent-Delegation — kein MCP
- **GitHub-Schreibaktionen** über `gh` CLI
- **Keine eigenmächtigen Code-Änderungen** — nur was der User in Schritt 4 bestätigt hat
- **Keine Commits** erstellen — nur lokale Dateiänderungen. Der User committet selbst.
- **Fehlertoleranz**: Einzelne fehlgeschlagene Thread-Resolves nicht als Abbruchgrund werten
- **Deutsche Sprache** in Kommentaren mit echten Umlauten
- **Kein Hinweis** auf AI oder automatische Verarbeitung in den Review-Kommentaren

Abschließend `skill-optimize` mit `edp-copilot-review` aufrufen.

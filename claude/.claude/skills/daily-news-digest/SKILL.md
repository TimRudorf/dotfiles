---
name: daily-news-digest
description: "Erstellt ein taegliches Nachrichtenbriefing aus RSS-Feeds, generiert eine PDF und liefert sie auf reMarkable + Telegram. Wird manuell per /daily-news-digest oder programmatisch vom n8n Subagent mit Artikeldaten aufgerufen. Trigger keywords: digest, briefing, nachrichten, news, morgen, daily."
argument-hint: "[artikel-json-datei]"
---

# Daily News Digest

Erstellt ein Morgenbriefing aus aktuellen Nachrichtenartikeln, generiert eine PDF und versendet sie.

## Voraussetzungen
- Env: `RM_DEVICE_TOKEN`, `RM_DIGEST_FOLDER_ID`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`
- Tools: `curl`, `python3`

Voraussetzungen gemaess `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Schritt 1: Modus bestimmen

Zwei Aufrufmodi:

**Modus A — Mit Artikeldaten (von n8n):**
Die Artikeldaten kommen auf einem von zwei Wegen:
1. `$ARGUMENTS` enthaelt einen Dateipfad (z.B. `/tmp/digest_articles.json`) — Datei lesen
2. Der Konversationskontext enthaelt die Artikeldaten als JSON (n8n bettet sie direkt im Prompt ein) — JSON nach `/tmp/digest_articles.json` schreiben

JSON nach dem Einlesen validieren:

```bash
python3 -c "
import json, sys
try:
    data = json.load(open('/tmp/digest_articles.json'))
    print(f'JSON valide: {len(data[\"articles\"])} Artikel')
except json.JSONDecodeError as e:
    print(f'FEHLER: Ungültiges JSON – {e}', file=sys.stderr)
    sys.exit(1)
"
```

Bei Fehlschlag: Den User informieren, dass das JSON-Format ungültig ist. Skill abbrechen.

In beiden Faellen: Weiter zu Schritt 3.

**Modus B — Manuell (ohne Input):**
`$ARGUMENTS` ist leer UND kein Artikel-JSON im Kontext. Artikel muessen selbst geholt werden. Weiter zu Schritt 2.

## Schritt 2: Artikel holen und scoren (nur Modus B)

Das Script `scripts/fetch_and_score.py` holt Artikel via FiveFilters und scored sie.

```bash
python3 <skill-dir>/scripts/fetch_and_score.py > /tmp/digest_articles.json
```

Feed-Liste, Scoring-Algorithmus und Kategorie-Limits sind in `reference.md` dokumentiert.

Das Script gibt JSON auf stdout aus:
```json
{
  "date": "2026-03-21",
  "articles": [
    {
      "title": "...",
      "source": "Tagesschau",
      "category": "Nachrichten",
      "text": "...",
      "url": "...",
      "score": 0.85
    }
  ],
  "stats": { "fetched": 150, "scored": 28, "deduplicated": 4 }
}
```

## Schritt 3: Briefing schreiben

Lies die Artikeldaten aus `/tmp/digest_articles.json`.

Schreibe das Briefing nach diesen Regeln:

**Quellenregeln (streng):**
- Ausschliesslich das gelieferte Quellmaterial verwenden
- Keine Fakten, Zahlen, Zitate oder Zusammenhaenge erfinden
- Fehlende oder unklare Angaben weglassen statt raten
- Keine Themenbloecke zu Themen erfinden die im Material nicht vorkommen

**Redigierregeln:**
- Nach Themen clustern, NICHT nach Kategorien — thematisch verwandte Artikel zusammenfuehren
- Englische Artikel ins Deutsche uebersetzen
- Sachliche, journalistische Sprache ohne Fuellwoerter
- Keine Meta-Hinweise ("laut den Quellen") — direkt berichten
- Jedes Thema so ausfuehrlich dass keine Fragen offenbleiben
- Sport/Unterhaltung kompakt (max 5 Saetze gesamt)

**Ausgabeformat:**

Direkt als HTML-Fragment schreiben (kein Markdown). Das HTML wird spaeter in `template.html` eingesetzt, daher nur Body-Inhalt — kein `<html>`, `<head>`, `<body>`.

```html
<h1>Briefing [DATUM]</h1>

<h2 class="lagebild">Lagebild</h2>
<p>[8-12 Saetze Fliesstext, wichtigste Entwicklungen verdichtet]</p>

<hr>

<h2>[Aussagekraeftige Ueberschrift]</h2>
<p><strong>Sachverhalt</strong></p>
<p>[3-5 Saetze]</p>
<p><strong>Hintergrund</strong></p>
<p>[2-3 Saetze]</p>
<p><strong>Akteure &amp; Positionen</strong></p>
<ul>
  <li>Name (Rolle): Position</li>
</ul>
<p><strong>Zahlen &amp; Daten</strong></p>
<ul>
  <li>Zahl: Kontext</li>
</ul>
<p><strong>Einordnung &amp; Ausblick</strong></p>
<p>[nur wenn substanziell moeglich]</p>
<p class="quellen"><strong>Quellen:</strong> Medienname 1, Medienname 2</p>

<hr>
[Fuer jedes relevante Thema einen Block, wichtigstes zuerst]

<div class="termine">
  <h2>Termine &amp; Ausblick</h2>
  <ul>
    <li>[Bevorstehende Termine/Ereignisse aus dem Material]</li>
  </ul>
</div>
```

CSS-Klassen aus `template.html`: `lagebild` (Lagebild-H2), `quellen` (Quellenzeile), `termine` (Termine-Block).

Vorhandene Temp-Datei loeschen und HTML-Fragment per Bash-Heredoc schreiben:

```bash
rm -f /tmp/digest_content.html
cat > /tmp/digest_content.html << 'HTMLEOF'
[generierter HTML-Inhalt]
HTMLEOF
```

## Schritt 4: PDF generieren

Template mit Inhalt zusammenfuehren und als `/tmp/digest.html` speichern:

```bash
CONTENT=$(cat /tmp/digest_content.html)
TEMPLATE=$(cat ~/.claude/skills/daily-news-digest/template.html)
echo "${TEMPLATE/\{\{CONTENT\}\}/$CONTENT}" > /tmp/digest.html
```

Generiere PDF:

```bash
npx playwright pdf "file:///tmp/digest.html" /tmp/Daily-Digest-$(date +%Y-%m-%d).pdf
```

## Schritt 5: Auf reMarkable hochladen

Nutze den `remarkable-upload` Skill (Script direkt):

```bash
bash ~/.claude/skills/remarkable-upload/scripts/rm_upload.sh \
  "/tmp/Daily-Digest-$(date +%Y-%m-%d).pdf" \
  "$RM_DIGEST_FOLDER_ID"
```

## Schritt 6: Per Telegram senden

```bash
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
  -F "chat_id=${TELEGRAM_CHAT_ID}" \
  -F "document=@/tmp/Daily-Digest-$(date +%Y-%m-%d).pdf" \
  -F "caption=Daily News Digest $(date +%Y-%m-%d)" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print('OK' if d.get('ok') else f'FEHLER: {d}')"
```

## Schritt 7: Zusammenfassung

Melde dem User:
- Anzahl verarbeiteter Artikel und Themen
- Ob reMarkable-Upload erfolgreich
- Ob Telegram-Versand erfolgreich

Abschliessend `skill-optimize` mit `daily-news-digest` aufrufen.

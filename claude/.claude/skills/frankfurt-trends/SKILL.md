---
name: frankfurt-trends
description: "Wöchentliche Erhebung der Food-, Café- und Bar-Trends in Frankfurt am Main mit Schwerpunkt auf dem Nordend (Berger Straße). Scrapet TikTok, Instagram und Google Maps via Apify, vergleicht mit Vorwoche, schreibt Briefing nach /workspace/data/frankfurt-trends/ und schickt Telegram-Notification. Trigger keywords: frankfurt trends, frankfurt food briefing, /frankfurt-trends, was ist gerade angesagt in frankfurt, frankfurt nordend empfehlung, mittwochs-briefing."
disable-model-invocation: true
---

# Frankfurt Trends Briefing

Wöchentliche Recherche zu Food/Café/Bar-Trends in Frankfurt mit Nordend-Fokus. Tim wohnt im Nordend (Berger Straße), hat kein eigenes Social Media und nutzt das Briefing als Empfehlungsbasis für Treffen mit Freunden.

## Voraussetzungen
- Env: `APIFY_TOKEN`
- Tools: `curl`, `python3`
- Datei: `/workspace/data/frankfurt-trends/` (Storage-Verzeichnis)

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Schritt 1: Budget-Check

Vor dem Run prüfen ob noch Apify-Budget da ist (Free-Tier $5/Monat, ein Run kostet ~$0,40).

```bash
curl -s -H "Authorization: Bearer $APIFY_TOKEN" \
  https://api.apify.com/v2/users/me/limits \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)['data']
used = d['current']['monthlyUsageUsd']
limit = d['limits']['maxMonthlyUsageUsd']
remaining = limit - used
print(f'Budget: \${used:.2f} / \${limit} | Verbleibend: \${remaining:.2f}')
sys.exit(0 if remaining >= 0.5 else 1)
"
```

Bei verbleibendem Budget < $0,50 abbrechen und Tim informieren.

## Schritt 2: Drei Apify-Scrapes parallel starten

Datum für Filenames: `RUN_DATE=$(date +%Y-%m-%d)`. Output-Pfade alle in `/workspace/data/frankfurt-trends/runs/`:
- `${RUN_DATE}_tiktok.json`
- `${RUN_DATE}_instagram.json`
- `${RUN_DATE}_gmaps.json`

**TikTok-Scraper** (`clockworks/tiktok-scraper`):
```bash
curl -s -X POST -H "Authorization: Bearer $APIFY_TOKEN" -H "Content-Type: application/json" \
  "https://api.apify.com/v2/acts/clockworks~tiktok-scraper/run-sync-get-dataset-items?timeout=180&memory=1024" \
  -d '{
    "hashtags": ["nordendfrankfurt", "bergerstraße", "frankfurtcafe", "frankfurtfoodguide"],
    "resultsPerPage": 12,
    "shouldDownloadVideos": false,
    "shouldDownloadCovers": false,
    "shouldDownloadSubtitles": false,
    "shouldDownloadSlideshowImages": false
  }' \
  -o /workspace/data/frankfurt-trends/runs/${RUN_DATE}_tiktok.json
```

**Instagram-Hashtag-Scraper** (`apify/instagram-hashtag-scraper`):
```bash
curl -s -X POST -H "Authorization: Bearer $APIFY_TOKEN" -H "Content-Type: application/json" \
  "https://api.apify.com/v2/acts/apify~instagram-hashtag-scraper/run-sync-get-dataset-items?timeout=180&memory=1024" \
  -d '{
    "hashtags": ["frankfurtnordend", "bergerstraße", "frankfurtcafe", "ffmcoffee"],
    "resultsLimit": 15
  }' \
  -o /workspace/data/frankfurt-trends/runs/${RUN_DATE}_instagram.json
```

**Google-Maps-Scraper** (`compass/crawler-google-places`):
```bash
curl -s -X POST -H "Authorization: Bearer $APIFY_TOKEN" -H "Content-Type: application/json" \
  "https://api.apify.com/v2/acts/compass~crawler-google-places/run-sync-get-dataset-items?timeout=180&memory=2048" \
  -d '{
    "searchStringsArray": ["Café Berger Straße Frankfurt", "Restaurant Nordend Frankfurt", "neue Cafés Frankfurt"],
    "locationQuery": "Frankfurt am Main",
    "maxCrawledPlacesPerSearch": 10,
    "language": "de",
    "skipClosedPlaces": true,
    "maxReviews": 0
  }' \
  -o /workspace/data/frankfurt-trends/runs/${RUN_DATE}_gmaps.json
```

## Schritt 3: Daten filtern & analysieren

Ein Python-Script für alle drei Datensätze:

```python
import json, re
from datetime import datetime, timezone, timedelta
from pathlib import Path

RUN_DATE = "YYYY-MM-DD"
BASE = Path("/workspace/data/frankfurt-trends/runs")

# === TikTok: dedupe + FFM-Filter + recent ===
tt = json.loads((BASE / f"{RUN_DATE}_tiktok.json").read_text())
seen = set(); tt_unique = [p for p in tt if p.get('id') not in seen and not seen.add(p['id'])]
def is_ffm(p):
    blob = ((p.get('text') or '') + ' ' +
            ' '.join([h.get('name','') for h in (p.get('hashtags') or [])])).lower()
    return any(k in blob for k in ['frankfurt','nordend','berger','069','ffm','mainhattan'])
ffm = [p for p in tt_unique if is_ffm(p)]
cutoff = datetime.now(timezone.utc) - timedelta(days=90)
recent = [p for p in ffm if p.get('createTimeISO') and
          datetime.fromisoformat(p['createTimeISO'].replace('Z','+00:00')) > cutoff]
top_tiktok = sorted(recent, key=lambda x: x.get('playCount',0) or 0, reverse=True)[:10]

# === Instagram: dedupe + nach Likes ===
ig = json.loads((BASE / f"{RUN_DATE}_instagram.json").read_text())
seen = set(); ig_unique = [p for p in ig if p.get('id') not in seen and not seen.add(p['id'])]
top_instagram = sorted(ig_unique, key=lambda x: x.get('likesCount',0) or 0, reverse=True)[:8]

# === Google Maps: Nordend/FFM filter ===
gm = json.loads((BASE / f"{RUN_DATE}_gmaps.json").read_text())
NORDEND_PLZ = ['60316','60318','60385']
def in_nordend(p): return any((p.get('postalCode') or '').startswith(z) for z in NORDEND_PLZ)
def in_ffm(p):
    pc = p.get('postalCode') or ''
    return pc.startswith('60') and (p.get('city','') or '').startswith('Frankfurt')
nordend_spots = [p for p in gm if in_nordend(p)]
other_ffm = [p for p in gm if in_ffm(p) and not in_nordend(p)]
def berger_nr(p):
    m = re.search(r'Berger Str\. (\d+)', p.get('address','') or '')
    return int(m.group(1)) if m else 99999
berger_cafes = sorted(
    [p for p in nordend_spots if 'Berger Str' in (p.get('address','') or '')],
    key=berger_nr
)
```

## Schritt 4: Vergleich mit Vorwoche

```python
prev_runs = sorted([f for f in BASE.glob("*.md") if re.match(r'\d{4}-\d{2}-\d{2}\.md', f.name)])
prev_date = prev_runs[-2].stem if len(prev_runs) >= 2 else None
```

Wenn Vorwoche existiert, das vorletzte Run-File für gleiche Quellen einlesen und vergleichen:
- **NEU:** TikTok-IDs heute in Top 10, die letzten Run nicht in Top 10 waren
- **WACHSEND:** Gleiche TikTok-ID mit >20% mehr Plays
- **GEFADET:** TikTok-IDs letzten Run in Top 10, jetzt nicht mehr
- **NEUE SPOTS:** Google-Maps-`placeId`s die letzten Run nicht aufgetaucht sind

Wenn keine Vorwoche da: Sektion „Delta zur Vorwoche" weglassen, stattdessen „Erster Run dieser Saison" notieren.

## Schritt 5: Briefing schreiben

Nach `/workspace/data/frankfurt-trends/runs/${RUN_DATE}.md` (siehe Baseline `2026-04-26.md` als Vorlage). Sektionen:

1. **Header** — Datum + 1-Satz-Einleitung
2. **Was diese Woche viral war (TikTok Top 10)** — Tabelle: Spot, Plays, Datum, Account
3. **Instagram-Highlights (Nordend/Café)** — Tabelle: Account/Spot, Likes, Notiz
4. **Berger Straße Cafés** — Tabelle nach Hausnummer
5. **Nordend Restaurants Top 10** — Tabelle: Name, Bewertung, Reviews, Küche, Adresse
6. **Andere FFM-Coffeehäuser** — kurz, mit Stadtteil
7. **Empfehlungslogik** — Kategorien:
   - Kaffee mit Freund/in im Nordend (zu Fuß von Berger Straße)
   - Mit Freunden essen — Nordend, sicher gut
   - Was gerade viral / im Hype ist
   - Specialty Coffee außerhalb Nordend (mit ÖPNV-Hinweis)
8. **Delta zur Vorwoche** (falls vorhanden) — NEU / WACHSEND / GEFADET / NEUE SPOTS
9. **Kosten dieses Runs** — Apify-Usage abfragen, Werte einfügen

**Stil:** Deutsch, knapp, Tabellen wo möglich. Tims Persona berücksichtigen (siehe `~/.claude/PERSONA.md`).

**Wichtig:** Nur Frankfurt-Stadt aufnehmen, kein Umland (kein Steinau, Bad Homburg, Neu-Isenburg, Großostheim etc.). Bei TikTok-Posts mit klar Umland-Spots (Text/Caption nennt Ortsnamen außerhalb Frankfurt) im Briefing weglassen.

## Schritt 6: Cheatsheet aktualisieren

`/workspace/data/frankfurt-trends/current-top.md` komplett neu schreiben mit den jetzt aktuellen Top-Spots. Format wie in der bestehenden Datei (Empfehlungen nach Anlass). Ziel: Wenn Tim ad-hoc fragt „was kann ich heute mit Freunden machen?", kann der Main-Agent diese Datei lesen und sofort antworten — ohne neuen Apify-Run.

## Schritt 7: History-Index ergänzen

Eine Zeile in `/workspace/data/frankfurt-trends/history-index.md` anhängen:

```markdown
| YYYY-MM-DD | [Run](runs/YYYY-MM-DD.md) | Kurzfazit (1 Satz, was war neu/herausragend) |
```

## Schritt 8: Kosten verifizieren

```bash
sleep 5
curl -s -H "Authorization: Bearer $APIFY_TOKEN" \
  "https://api.apify.com/v2/users/me/usage/monthly" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)['data']
print(f'Total Monat: \${d[\"totalUsageCreditsUsdAfterVolumeDiscount\"]:.4f}')
"
```

Wert ins Briefing eintragen (Sektion „Kosten dieses Runs").

## Schritt 9: Telegram-Notification

Kurzfazit (3-5 Bullets) via `mcp__bridge__notify_user`:

```
📍 Frankfurt-Trends Briefing YYYY-MM-DD ist da

Diese Woche:
• <Top-Viral-Spot der Woche>
• <Wichtigste Neueröffnung>
• <Wichtigste Veränderung zur Vorwoche>

Volltext: /workspace/data/frankfurt-trends/runs/YYYY-MM-DD.md
Cheatsheet: /workspace/data/frankfurt-trends/current-top.md

Kosten dieses Runs: $X.XX | Restbudget: $Y.YY
```

## Schritt 10: Skill-Optimierung

Abschließend `skill-optimize` mit `frankfurt-trends` aufrufen.

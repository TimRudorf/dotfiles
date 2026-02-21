---
name: mealie-import
description: Imports a recipe from Markdown into Mealie. Use when asked to "import a recipe", "add recipe to Mealie", "Rezept importieren", or given a markdown recipe to upload.
disable-model-invocation: true
allowed-tools: Read, Write, Bash, AskUserQuestion, Glob
argument-hint: "[path/to/recipe.md | inline markdown text]"
---

# Rezept in Mealie importieren

Importiert ein Rezept aus Markdown in die Mealie-Instanz unter `https://mealie.timrudorf.de`.

## Konfiguration

**Env-Datei:** `/Users/timrudorf/Nextcloud/Rezepte/.env` enthält `MEALIE_URL`, `MEALIE_TOKEN`, `PEXELS_TOKEN` (optional, Stockfotos) und `OPENAI_TOKEN` (optional, KI-Bildgenerierung).

**WICHTIG:** Jeder `Bash`-Aufruf braucht `source /Users/timrudorf/Nextcloud/Rezepte/.env` am Anfang, da Shell-State zwischen Aufrufen nicht persistiert. Newlines oder Semikolons verwenden, **NICHT `&&`** für `source`+`curl`-Verkettung (Variablen kommen sonst nicht an → "No host part in URL").

## Schritt 1: Input ermitteln

- `$ARGUMENTS` endet auf `.md` und Datei existiert → Datei mit `Read` lesen, Pfad merken für Löschung in Schritt 8
- `$ARGUMENTS` ist kein gültiger Dateipfad → als Inline-Markdown behandeln
- `$ARGUMENTS` leer → per `AskUserQuestion` nach Rezept-Pfad oder -Text fragen

## Schritt 2: Markdown parsen

Aus dem Markdown-Text folgende Felder extrahieren:

| Feld | Herkunft |
|------|----------|
| `name` | Erste Überschrift oder erste Zeile |
| `description` | Erste(r) Satz/Absatz nach dem Titel |
| `recipeIngredient` | Aufzählungsliste unter "Zutaten"/"Ingredients" — **strukturiert parsen** (siehe unten) |
| `recipeInstructions` | Nummerierte Schritte unter "Zubereitung"/"Schritte"/"Steps" |
| `notes` | Abschnitte unter "Notizen"/"Notes"/"Tipps"/"Hinweise" |
| `prepTime`, `cookTime`, `performTime`, `totalTime` | Aus dem Text ableiten, ISO 8601 Duration (z.B. `PT30M`, `PT1H`) |
| `recipeYield` | Menge/Portionen aus dem Text (z.B. "1 Laib", "4 Portionen") |
| `recipeServings` | Numerischer Wert der Portionszahl (z.B. `4` bei "4 Portionen", `1` bei "1 Glas") |
| Tags | Aus Kontext ableiten (z.B. Zutaten, Zubereitungsart) |
| Kategorien | Aus Kontext ableiten (z.B. "Brot", "Kuchen", "Hauptgericht") |
| Utensilien | Aus Zubereitungstext ableiten (siehe Utensilien-Erkennung unten) |

### Utensilien aus Rezepttext ableiten

Zubereitungsschritte nach Schlüsselwörtern durchsuchen und passende Utensilien zuordnen:

| Rezepttext enthält | Tool |
|-------------------|------|
| Topf, kochen, erhitzen, köcheln | Topf |
| Pfanne, anbraten, braten | Pfanne |
| Ofen, backen, überbacken | Backofen |
| Mixer, pürieren, mixen | Mixer / Pürierstab |
| Schüssel, verrühren, vermengen | Rührschüssel |
| Schneidebrett, schneiden, würfeln | Schneidebrett |
| Weck-Glas, einkochen, einmachen | Einmachglas |
| Sieb, abseihen, abtropfen | Sieb |
| Reibe, reiben | Reibe |
| Waage, abwiegen | Küchenwaage |
| Backblech | Backblech |
| Auflaufform | Auflaufform |
| Thermometer | Küchenthermometer |

### Zutaten strukturiert parsen

Jede Zutat in ihre Bestandteile zerlegen:

| Beispiel | quantity | unit | food | note |
|----------|----------|------|------|------|
| `300 g gefrorene Himbeeren` | 300 | g | Himbeeren | gefroren |
| `2 EL Chia-Samen (ca. 20 g)` | 2 | EL | Chia-Samen | ca. 20 g |
| `1 Banane` | 1 | (leer) | Banane | |
| `Saft einer Zitrone` | 0 | (leer) | Zitronensaft | |
| `Salz und Pfeffer` | 0 | (leer) | (leer) | Salz und Pfeffer |

**Parsing-Regeln:**
1. Zahl am Anfang → `quantity`
2. Bekannte Einheit nach der Zahl → `unit` (g, kg, ml, l, EL, TL, Stück, Prise, Bund, Packung, etc.)
3. Hauptzutat (Nomen) → `food`
4. Adjektive/Qualifier (gefroren, frisch, gehackt) und Klammerzusätze → `note`
5. Wenn keine klare Trennung möglich → alles in `note`, `food` leer lassen

**Ergebnis dem User als Zusammenfassung zeigen** und per `AskUserQuestion` bestätigen lassen:

> Rezept erkannt:
> Name: ...
> Beschreibung: ...
> Zutaten: X Einträge
> Schritte: X Einträge
> Utensilien: [Topf, Schneidebrett, ...]
> Notizen: X Einträge
> Tags: [...]
> Kategorie: [...]
> Zeiten: Vorbereitung X, Kochen Y, Gesamt Z
> Bild: wird automatisch gesetzt (KI-generiert / Stockfoto)

Optionen: **"Importieren"**, **"Ändern"**, **"Abbrechen"**

- **Importieren** → weiter zu Schritt 3
- **Ändern** → User nach gewünschten Änderungen fragen, erneut bestätigen
- **Abbrechen** → Skill beenden

## Schritt 3: Rezept erstellen (POST)

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
SLUG=$(curl -s -X POST "$MEALIE_URL/api/recipes" \
  -H "Authorization: Bearer $MEALIE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "REZEPTNAME"}')
echo "Slug: $SLUG"
```

Rückgabe ist der Slug als JSON-String (z.B. `"mischbrot-mit-sauerteig-roggen-vollkorn"`). Die Anführungszeichen entfernen.

Danach die Recipe-ID abrufen:

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
curl -s -H "Authorization: Bearer $MEALIE_TOKEN" \
  "$MEALIE_URL/api/recipes/$SLUG" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])"
```

## Schritt 4: Tags, Kategorien, Units und Foods anlegen

### 4a: Existierende Tags/Kategorien abfragen (parallel)

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
curl -s -H "Authorization: Bearer $MEALIE_TOKEN" "$MEALIE_URL/api/organizers/tags" | python3 -c "import sys,json; [print(f'{t[\"id\"]} {t[\"name\"]}') for t in json.load(sys.stdin).get('items',[])]"
```

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
curl -s -H "Authorization: Bearer $MEALIE_TOKEN" "$MEALIE_URL/api/organizers/categories" | python3 -c "import sys,json; [print(f'{c[\"id\"]} {c[\"name\"]}') for c in json.load(sys.stdin).get('items',[])]"
```

### 4a-2: Fehlende Tags/Kategorien anlegen

Für jeden Tag der noch nicht existiert:

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
curl -s -X POST "$MEALIE_URL/api/organizers/tags" \
  -H "Authorization: Bearer $MEALIE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "TAGNAME"}'
```

Für jede Kategorie die noch nicht existiert:

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
curl -s -X POST "$MEALIE_URL/api/organizers/categories" \
  -H "Authorization: Bearer $MEALIE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "KATEGORIENAME"}'
```

**Echte UUIDs aus den API-Responses sammeln** — diese werden in Schritt 6 gebraucht.

### 4b: Units matchen/anlegen

**Oberste Regel:** Keine Duplikate! Existierende Units immer wiederverwenden.

**Alle existierenden Units laden:**

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
curl -s -H "Authorization: Bearer $MEALIE_TOKEN" "$MEALIE_URL/api/units?perPage=100" | python3 -c "
import sys,json
data=json.load(sys.stdin)
for u in data.get('items',[]):
    print(f'{u[\"id\"]} | {u.get(\"abbreviation\",\"\")} | {u[\"name\"]}')
"
```

**Unit-Mapping:** Siehe `reference.md` → Abschnitt "Unit-Mapping" für die vollständige Tabelle (g, kg, ml, l, EL, TL, Stück, Prise, Bund, Packung).

**Match-Algorithmus:**
1. Exakter `abbreviation`-Match (case-insensitive)
2. `name` enthält den Suchbegriff (case-insensitive) — deutsch oder englisch
3. **Nur wenn kein Match** → neue Unit anlegen:

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
curl -s -X POST "$MEALIE_URL/api/units" \
  -H "Authorization: Bearer $MEALIE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Gramm", "abbreviation": "g", "pluralName": "Gramm"}'
```

→ 201 + UUID zurück. Diese UUID für die Ingredient-Referenz verwenden.

### 4c: Foods matchen/anlegen

**Oberste Regel:** Keine Duplikate! Mealie hat ~2687 vorinstallierte Foods (meist englisch).

**Food suchen (per Search-Parameter, effizienter als alle laden):**

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
curl -s -H "Authorization: Bearer $MEALIE_TOKEN" "$MEALIE_URL/api/foods?search=SUCHBEGRIFF&perPage=10" | python3 -c "
import sys,json
data=json.load(sys.stdin)
for f in data.get('items',[]):
    print(f'{f[\"id\"]} | {f[\"name\"]}')
"
```

**Match-Algorithmus:**
1. `GET /api/foods?search=FOODNAME` — API-Suche nutzen (liefert Teilmatches)
2. Aus den Ergebnissen: exakter Name-Match (case-insensitive) bevorzugen
3. Falls kein exakter Match aber ähnliche Treffer → den besten verwenden
4. **Nur wenn gar kein Match** → neues Food anlegen:

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
curl -s -X POST "$MEALIE_URL/api/foods" \
  -H "Authorization: Bearer $MEALIE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Himbeeren"}'
```

→ 201 + UUID zurück. Diese UUID für die Ingredient-Referenz verwenden.

**Tipp:** Units nur einmal am Anfang laden (es gibt ~26 Stück). Foods pro Zutat einzeln suchen (zu viele für Bulk-Load).

### 4d: Tools matchen/anlegen

Analog zu Tags/Kategorien: Utensilien (aus Schritt 2 abgeleitet) gegen existierende Tools matchen.

**Alle existierenden Tools laden:**

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
curl -s -H "Authorization: Bearer $MEALIE_TOKEN" "$MEALIE_URL/api/organizers/tools" | python3 -c "
import sys,json
data=json.load(sys.stdin)
for t in data.get('items',[]):
    print(f'{t[\"id\"]} | {t[\"name\"]} | {t[\"slug\"]}')
"
```

**Match-Algorithmus:**
1. Case-insensitive Name-Match gegen existierende Tools
2. **Nur wenn kein Match** → neues Tool anlegen:

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
curl -s -X POST "$MEALIE_URL/api/organizers/tools" \
  -H "Authorization: Bearer $MEALIE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Topf"}'
```

→ 201 + `{id, name, slug}` zurück. Alle drei Felder (id, name, slug) für Schritt 6b sammeln.

## Schritt 5: PATCH 1 — Hauptdaten (OHNE Tags/Kategorien!)

> **⚠ KRITISCH:** Niemals `tags` oder `recipeCategory` in diesem PATCH senden! Siehe API-Quirks unten.

JSON-Payload als Python-Datei in `/tmp/mealie_recipe_update.json` schreiben, dann per `curl -d @datei` senden. Das ist Umlaut-sicher.

### Payload-Struktur

```python
import json, uuid

data = {
    "name": "Rezeptname",
    "description": "Beschreibung",
    "recipeYield": "ca. 240 ml (1 Weck-Glas)",  # Freitext-Ertrag
    "recipeServings": 1,           # ← NEU: Numerisch für Skalierungs-Slider
    "recipeYieldQuantity": 1,      # ← NEU: Numerische Portionszahl
    "prepTime": "PT30M",           # ISO 8601 Duration
    "cookTime": "PT50M",
    "totalTime": "PT16H",
    # ⚠ KRITISCH: unit/food brauchen echte IDs aus /api/units bzw. /api/foods!
    # Nur {"name": "..."} OHNE id → 500 ValueError.
    # Entweder {"id": "ECHTE-UUID", "name": "..."} oder None.
    "recipeIngredient": [
        {
            "quantity": 300,
            "unit": {"id": "ECHTE-UUID-AUS-SCHRITT-4b", "name": "Gramm"},
            "food": {"id": "ECHTE-UUID-AUS-SCHRITT-4c", "name": "Himbeeren"},
            "note": "gefroren",     # Nur Qualifier/Zusatzinfo
            "referenceId": str(uuid.uuid4())
        },
        {
            "quantity": 1,
            "unit": None,           # Keine Einheit → None
            "food": {"id": "ECHTE-UUID", "name": "Banane"},
            "note": "",
            "referenceId": str(uuid.uuid4())
        },
        {
            "quantity": 0,
            "unit": None,
            "food": None,           # Kein klares Food → None
            "note": "Salz und Pfeffer",  # Alles in note
            "referenceId": str(uuid.uuid4())
        }
        # ... weitere Zutaten
    ],
    "recipeInstructions": [
        {
            "id": str(uuid.uuid4()),
            "title": "",
            "text": "**Schritt-Titel:** Beschreibung...",
            "ingredientReferences": []     # PFLICHTFELD, auch wenn leer!
        }
        # ... weitere Schritte
    ],
    "notes": [
        {"title": "Notiz-Titel", "text": "Inhalt..."}
        # ... weitere Notizen
    ]
}

with open('/tmp/mealie_recipe_update.json', 'w') as f:
    json.dump(data, f, ensure_ascii=False)
```

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
HTTP_CODE=$(curl -s -o /tmp/mealie_response.txt -w "%{http_code}" -X PATCH "$MEALIE_URL/api/recipes/$SLUG" \
  -H "Authorization: Bearer $MEALIE_TOKEN" \
  -H "Content-Type: application/json" \
  -d @/tmp/mealie_recipe_update.json)
echo "Status: $HTTP_CODE"
```

Erwarteter Status: **200**. Bei Fehler → `cat /tmp/mealie_response.txt` für Details. Häufigste Ursachen siehe API-Quirks.

## Schritt 6a: PATCH 2 — Tags und Kategorien (separater Call!)

> **⚠ KRITISCH:** Dieser PATCH darf NUR `name`, `tags` und `recipeCategory` enthalten. Kein `recipeInstructions` etc.!

```python
import json

tag_data = {
    "name": "Rezeptname",
    "tags": [
        {"id": "ECHTE-UUID", "name": "Tagname", "slug": "tagname"}
        # ... weitere Tags mit echten IDs aus Schritt 4
    ],
    "recipeCategory": [
        {"id": "ECHTE-UUID", "name": "Kategorie", "slug": "kategorie"}
        # ... weitere Kategorien mit echten IDs aus Schritt 4
    ]
}

with open('/tmp/mealie_tags_update.json', 'w') as f:
    json.dump(tag_data, f, ensure_ascii=False)
```

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
HTTP_CODE=$(curl -s -o /tmp/mealie_response.txt -w "%{http_code}" -X PATCH "$MEALIE_URL/api/recipes/$SLUG" \
  -H "Authorization: Bearer $MEALIE_TOKEN" \
  -H "Content-Type: application/json" \
  -d @/tmp/mealie_tags_update.json)
echo "Status: $HTTP_CODE"
```

Erwarteter Status: **200**. Bei Fehler → `cat /tmp/mealie_response.txt` für Details.

## Schritt 6b: PATCH 3 — Tools (separater Call!)

> **⚠ KRITISCH:** Analog zu Tags: `tools` in einem eigenen PATCH-Call senden, **nicht** im selben Call wie `recipeInstructions` oder `tags`.

```python
import json

tool_data = {
    "name": "Rezeptname",
    "tools": [
        {"id": "ECHTE-UUID", "name": "Topf", "slug": "topf"},
        {"id": "ECHTE-UUID", "name": "Schneidebrett", "slug": "schneidebrett"}
        # ... weitere Tools mit echten IDs aus Schritt 4d
    ]
}

with open('/tmp/mealie_tools_update.json', 'w') as f:
    json.dump(tool_data, f, ensure_ascii=False)
```

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
HTTP_CODE=$(curl -s -o /tmp/mealie_response.txt -w "%{http_code}" -X PATCH "$MEALIE_URL/api/recipes/$SLUG" \
  -H "Authorization: Bearer $MEALIE_TOKEN" \
  -H "Content-Type: application/json" \
  -d @/tmp/mealie_tools_update.json)
echo "Status: $HTTP_CODE"
```

Erwarteter Status: **200**. RecipeTool-Schema braucht alle 3 Felder: `id`, `name`, `slug`.

## Schritt 7a: Verifizieren

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
curl -s -H "Authorization: Bearer $MEALIE_TOKEN" \
  "$MEALIE_URL/api/recipes/$SLUG" -o /tmp/mealie_verify.json
python3 -c "
import json
with open('/tmp/mealie_verify.json') as f:
    d=json.load(f)
print(f'Name: {d[\"name\"]}')
print(f'Portionen: {d.get(\"recipeServings\",\"nicht gesetzt\")}')
print(f'Tags: {[t[\"name\"] for t in d.get(\"tags\",[])]}')
print(f'Kategorie: {[c[\"name\"] for c in d.get(\"recipeCategory\",[])]}')
print(f'Utensilien: {[t[\"name\"] for t in d.get(\"tools\",[])]}')
print(f'Bild: {\"gesetzt\" if d.get(\"image\") else \"nicht gesetzt\"}')
print(f'Zutaten: {len(d[\"recipeIngredient\"])}')
units_set = sum(1 for i in d['recipeIngredient'] if i.get('unit'))
foods_set = sum(1 for i in d['recipeIngredient'] if i.get('food'))
print(f'  → mit Unit: {units_set}, mit Food: {foods_set}')
print(f'Schritte: {len(d[\"recipeInstructions\"])}')
print(f'Notizen: {len(d.get(\"notes\",[]))}')
print(f'URL: https://mealie.timrudorf.de/g/home/r/{d[\"slug\"]}')
"
```

Prüfen ob alle Felder korrekt gefüllt sind (inkl. Tools und Bild). Bei Diskrepanz → User informieren.

## Schritt 7b: Rezeptbild setzen (KI-generiert / Stockfoto / kein Bild)

**Nach** dem Verifizieren, **vor** dem Quelldatei-Löschen. Vollständige Code-Beispiele: siehe `reference.md` → "Rezeptbild-Workflow".

### Automatische Strategie

Verfügbare Keys prüfen (`source .env`):
- `OPENAI_TOKEN` gesetzt → **KI-Bild generieren** (bevorzugt, direkt verwenden ohne Rückfrage)
- Nur `PEXELS_TOKEN` → **Stockfoto** (bestes Ergebnis automatisch wählen)
- Keines gesetzt → Schritt überspringen, User informieren

### KI-Bild generieren (wenn `OPENAI_TOKEN` verfügbar)

1. **Prompt bauen:** `Professional food photography of {name}. {description}. Key ingredients: {top 3-4}. Style: overhead shot, natural lighting, rustic setting, appetizing presentation, realistic photograph.`
2. **OpenAI API** aufrufen (`gpt-image-1`, `1536x1024`, `medium`) — Payload über Temp-Datei
3. **base64 dekodieren** → `/tmp/mealie_recipe_image.png`
4. **Direkt hochladen** — keine Vorschau/Bestätigung nötig

### Stockfoto-Fallback (wenn nur `PEXELS_TOKEN`)

1. **Englische Suchbegriffe** ableiten (Pexels hat kaum deutsche Inhalte)
2. **1 Ergebnis** holen (`per_page=1`, `orientation=landscape`)
3. Direkt verwenden

### Bild hochladen

- **KI-Bild (lokal):** `PUT /api/recipes/{slug}/image` multipart (`image` + `extension`)
- **Stockfoto (URL):** `POST /api/recipes/{slug}/image` mit `{"url": "..."}`

Erwarteter Status: **200**. Temp-Dateien werden in Schritt 8 aufgeräumt.

## Schritt 8: Quelldatei löschen

**Nur wenn der Input eine Datei war** (Schritt 1): Die Quelldatei löschen.

```bash
rm "DATEIPFAD"
```

Temporäre JSON-Dateien aufräumen:

```bash
rm -f /tmp/mealie_recipe_update.json /tmp/mealie_tags_update.json /tmp/mealie_tools_update.json /tmp/mealie_image_prompt.json /tmp/mealie_image_response.json /tmp/mealie_recipe_image.png
```

## Schritt 9: Ergebnis anzeigen

Zusammenfassung ausgeben:

```
✅ Rezept importiert!
Name: ...
URL: https://mealie.timrudorf.de/g/home/r/{slug}
Portionen: X (skalierbar)
Bild: ✅ KI-generiert / ✅ Stockfoto / ⚠ kein API-Key / ❌ übersprungen
Tags: [...]
Kategorie: [...]
Utensilien: [...]
Zutaten: X (davon Y mit Unit, Z mit Food) | Schritte: A | Notizen: B
Quelldatei: gelöscht / (kein Datei-Input)
```

---

## API-Quirks

> **Vollständige Dokumentation:** Siehe `reference.md` → Abschnitt "API-Quirks".

**Wichtigste Regeln (Kurzfassung):**
- `unit`/`food` brauchen echte UUIDs — nur `{"name":...}` ohne `id` → 500
- `tags`/`recipeCategory` **nie** im selben PATCH wie `recipeInstructions` → 500
- `tools` ebenfalls **separater** PATCH (braucht `id`, `name`, `slug`)
- `ingredientReferences: []` ist Pflichtfeld in jeder Instruktion
- Jede Instruktion braucht `id` (UUID v4)
- Payload immer über Temp-Datei + `curl -d @datei`
- `source .env` in **jedem** Bash-Aufruf
- Pexels Env-Var heißt `PEXELS_TOKEN`

---

## Skill-Optimierung

Nach Abschluss dieses Skills kurz bewerten, ob Optimierungsbedarf besteht:

- **Empfehlung "ja"**: Fehler aufgetreten, Workarounds nötig, Befehle wiederholt, User-Korrekturen
- **Empfehlung "nein"**: Reibungsloser Lauf wie dokumentiert

Per `AskUserQuestion` fragen:

> Skill abgeschlossen. Soll die Skill-Dokumentation optimiert werden?
> Empfehlung: {ja — [kurzer Grund] | nein — Lauf war reibungslos}

Optionen: **"Ja, optimieren"**, **"Nein"**

Bei "Ja": `skill-optimize` mit Skill-Name `mealie-import` ausführen.

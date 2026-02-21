# Mealie API Reference

## API-Quirks (dokumentiert aus Praxis)

### unit/food brauchen echte IDs
`recipeIngredient` mit `unit: {"name": "grams"}` oder `food: {"name": "..."}` **ohne `id`** verursacht **500 ValueError**. Units/Foods müssen über `/api/units` bzw. `/api/foods` angelegt/abgefragt werden, damit eine echte UUID vorhanden ist. Korrekt: `{"id": "ECHTE-UUID", "name": "Gramm"}`. Ohne Unit/Food: `null` setzen.

### Tags/Kategorien-Bug
Niemals `tags` oder `recipeCategory` im selben PATCH wie `recipeInstructions` senden → **500 TypeError**. Immer in einem separaten PATCH-Call (Schritt 5 vs. Schritt 6).

### ingredientReferences ist Pflichtfeld
Jede `recipeInstructions`-Instruktion **muss** das Feld `ingredientReferences` enthalten, auch wenn leer (`[]`). Ohne dieses Feld → **500 TypeError**.

### Instruktions-ID ist Pflichtfeld
Jede Instruktion braucht ein `id`-Feld mit einer UUID v4. Ohne → **500 TypeError**.

### Zwei-Schritt-Erstellung
Rezepte können nicht in einem einzigen POST mit allen Daten erstellt werden. Ablauf: POST (nur Name → Slug) → PATCH (Details).

### UUIDs müssen v4 sein
Tags und Kategorien brauchen echte UUID v4 aus der Organizers-API. Fake-UUIDs → **422 "UUID version 4 expected"**.

### camelCase-Felder
Die API nutzt camelCase, nicht snake_case: `recipeIngredient`, `recipeInstructions`, `recipeCategory`, `prepTime`, `performTime`, `cookTime`, `totalTime`, `recipeYield`.

### Payload über Temp-Datei
JSON in eine Datei schreiben, dann `curl -d @datei` nutzen. Das ist sicherer als Inline-JSON im Shell (Umlaute, Sonderzeichen, Escaping). Auch für `curl`-Responses: `-o /tmp/datei.json` statt Pipe nach `python3` (vermeidet leere Responses bei großen Payloads).

### curl Status-Code zuverlässig erfassen
**Nicht** `curl -w "\n%{http_code}" | grep` verwenden (liefert `000` oder leere Ausgabe). Stattdessen: `HTTP_CODE=$(curl -s -o /tmp/mealie_response.txt -w "%{http_code}" ...)` und dann `echo "Status: $HTTP_CODE"`.

### Shell-State resettet
`source .env` muss in **jedem** Bash-Aufruf stehen, da Umgebungsvariablen zwischen Tool-Aufrufen nicht persistieren. Newlines oder Semikolons verwenden, **nicht `&&`** für `source`+`curl`-Verkettung.

### Tools separat PATCHen
Analog zu Tags/Kategorien: `tools` in einem eigenen PATCH-Call senden, **nicht** im selben Call wie `recipeInstructions` oder `tags`. RecipeTool-Schema braucht alle 3 Felder: `id`, `name`, `slug`.

### Bild via POST scrapen (URL)
`POST /api/recipes/{slug}/image` mit `{"url": "..."}` lässt Mealie das Bild selbst herunterladen. Kein multipart-Upload nötig. Response: 200 + `null`. Geeignet für Stockfoto-URLs (Pexels). Env-Var heißt `PEXELS_TOKEN` (nicht `PEXELS_API_KEY`).

### Bild via PUT hochladen (lokale Datei)
`PUT /api/recipes/{slug}/image` mit multipart/form-data. Felder:
- `image`: Die Bilddatei (z.B. `@/tmp/mealie_recipe_image.png`)
- `extension`: Dateiendung (z.B. `.png`)

```bash
curl -s -X PUT "$MEALIE_URL/api/recipes/$SLUG/image" \
  -H "Authorization: Bearer $MEALIE_TOKEN" \
  -F "image=@/tmp/mealie_recipe_image.png" \
  -F "extension=.png"
```

Response: 200. Geeignet für lokal generierte Bilder (z.B. via OpenAI API).

---

## Unit-Mapping (deutsche Abkürzung → Mealie-Unit)

| Rezept-Text | Match-Strategie |
|-------------|----------------|
| g, Gramm | `abbreviation: "g"` oder `name` enthält "gram"/"Gramm" |
| kg | `abbreviation: "kg"` oder `name: "kilogram"` |
| ml | `abbreviation: "ml"` oder `name: "milliliter"` |
| l, Liter | `name: "liter"` |
| EL, Esslöffel | `name: "tablespoon"/"Esslöffel"` |
| TL, Teelöffel | `name: "teaspoon"/"Teelöffel"` |
| Stück, Stk | `name: "piece"/"Stück"` |
| Prise | `name: "pinch"/"Prise"` |
| Bund | `name: "bunch"/"Bund"` |
| Packung, Pkg | `name: "package"/"Packung"` |

---

## Rezeptbild-Workflow (Code-Beispiele)

### KI-Bild generieren (OpenAI gpt-image-1)

**Prompt als JSON-Datei schreiben:**

```python
import json

prompt_data = {
    "model": "gpt-image-1",
    "prompt": "Professional food photography of {name}. {description}. Key ingredients: {top 3-4}. Style: overhead shot, natural lighting, rustic setting, appetizing presentation, realistic photograph.",
    "n": 1,
    "size": "1536x1024",
    "quality": "medium"
}

with open('/tmp/mealie_image_prompt.json', 'w') as f:
    json.dump(prompt_data, f, ensure_ascii=False)
```

**API-Call:**

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
curl -s -X POST "https://api.openai.com/v1/images/generations" \
  -H "Authorization: Bearer $OPENAI_TOKEN" \
  -H "Content-Type: application/json" \
  -d @/tmp/mealie_image_prompt.json \
  -o /tmp/mealie_image_response.json
```

**Wichtig:** `gpt-image-1` liefert **immer** base64 (`data[0].b64_json`), unabhängig von `response_format`.

**base64 dekodieren:**

```bash
python3 -c "
import json, base64
with open('/tmp/mealie_image_response.json') as f:
    data = json.load(f)
b64 = data['data'][0]['b64_json']
with open('/tmp/mealie_recipe_image.png', 'wb') as f:
    f.write(base64.b64decode(b64))
print('Bild gespeichert: /tmp/mealie_recipe_image.png')
"
```

**Vorschau (macOS):** `open /tmp/mealie_recipe_image.png`

### Stockfoto suchen (Pexels)

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
curl -s -H "Authorization: $PEXELS_TOKEN" \
  "https://api.pexels.com/v1/search?query=ENGLISCHER_SUCHBEGRIFF&per_page=5&orientation=landscape" \
  | python3 -c "
import sys,json
d=json.load(sys.stdin)
if not d.get('photos'):
    print('KEINE_TREFFER')
else:
    for i,p in enumerate(d['photos'],1):
        print(f'{i}. {p[\"src\"][\"large\"]}')
"
```

**Suchstrategie:** Rezeptname ins Englische übersetzen. Fallback: Hauptzutat (englisch).

### Bild hochladen

**KI-Bild (lokale Datei) → multipart PUT:**

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
curl -s -X PUT "$MEALIE_URL/api/recipes/$SLUG/image" \
  -H "Authorization: Bearer $MEALIE_TOKEN" \
  -F "image=@/tmp/mealie_recipe_image.png" \
  -F "extension=.png"
```

**Stockfoto (URL) → POST:**

```bash
source /Users/timrudorf/Nextcloud/Rezepte/.env
curl -s -X POST "$MEALIE_URL/api/recipes/$SLUG/image" \
  -H "Authorization: Bearer $MEALIE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"url": "PEXELS_IMAGE_URL"}'
```

---

## OpenAI Image API — Kurzreferenz

**Endpoint:** `POST https://api.openai.com/v1/images/generations`

**Auth:** `Authorization: Bearer $OPENAI_TOKEN`

**Model:** `gpt-image-1`

**Payload:**
```json
{
  "model": "gpt-image-1",
  "prompt": "Professional food photography of ...",
  "n": 1,
  "size": "1536x1024",
  "quality": "medium"
}
```

**Verfügbare Sizes:** `1024x1024`, `1536x1024` (landscape), `1024x1536` (portrait)

**Quality:** `low` (~$0.01), `medium` (~$0.04), `high` (~$0.08)

**Response-Format:** `gpt-image-1` liefert **immer** base64 in `data[0].b64_json`, unabhängig von `response_format`.

**Kosten:** ~$0.04 pro Bild bei `medium` quality, `1536x1024`.

**Env-Var:** `OPENAI_TOKEN` in `/Users/timrudorf/Nextcloud/Rezepte/.env`

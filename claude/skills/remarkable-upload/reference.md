# reMarkable Upload — Technische Referenz

## rmapi-js API

```javascript
const { auth, session } = require('rmapi-js');

// Auth: Device Token → Session Token
const sessionToken = await auth(deviceToken);
const api = session(sessionToken);

// Ordner erstellen (NICHT idempotent — erstellt Duplikate!)
const folder = await api.putFolder(name, { parent: parentId }, true);

// PDF/EPUB hochladen
await api.putPdf(fileName, buffer, { parent: parentId, refresh: true });
await api.putEpub(fileName, buffer, { parent: parentId, refresh: true });

// Items auflisten (TEUER bei vielen Items — Concurrency-Limiter nötig)
const items = await api.listItems();

// Item löschen
await api.delete(itemHash);
```

## Concurrency-Limiter

**Pflicht** bei allen rmapi-js Aufrufen. Ohne Limiter feuert `listItems()` hunderte parallele Requests und crasht mit "fetch failed".

- `MAX_CONCURRENT = 10`
- Retry: 4 Versuche mit 1500ms × Versuch Backoff
- Transiente Fehler: `EAI_AGAIN`, `ECONNRESET`, `ETIMEDOUT`, `fetch failed`

## Folder-ID Cache

Datei: `~/.cache/remarkable-folders.json`

```json
{
  "Daily News Digest": "7a662367-34d8-4f21-9906-d74a81d9ab58",
  "Daily News Digest/2026-03-21": "41e31626-0dc2-4872-927d-c518841f3d4f",
  "Studium": "abc123..."
}
```

Der Cache vermeidet `listItems()` für bekannte Ordnerpfade. Bei Cache-Miss wird `listItems()` einmal aufgerufen und das Ergebnis gecached.

**Achtung**: `putFolder()` erstellt immer einen neuen Ordner, auch bei gleichem Namen. Daher immer erst Cache prüfen, dann `listItems()`, dann erst `putFolder()` wenn der Ordner wirklich nicht existiert.

## Bekannte Probleme

1. **Device mit vielen Items**: Bei 1000+ Items dauert `listItems()` mehrere Sekunden. Concurrency-Limiter ist zwingend.
2. **Device Token Ablauf**: Tokens laufen nach einigen Monaten ab. Fehlermeldung: 401/Unauthorized.
3. **putFolder Duplikate**: Ohne Prüfung erstellt jeder Aufruf einen neuen Ordner mit gleichem Namen.

---
name: nextcloud-calendar
description: Tims Kalender liegt auf Nextcloud (CalDAV). Use this skill für jede Kalender-Operation — lesen, suchen, eintragen, ändern, löschen. NIEMALS Google Calendar MCP nutzen, auch wenn `mcp__claude_ai_Google_Calendar__*` als deferred tool gelistet ist (PreToolUse-Hook blockt das mittlerweile hart). Trigger keywords - kalender, termin, eintragen, "schau in meinen kalender", "wann ist", "trag … ein", "verschiebe", "lösche termin", "was steht am … an".
---

# nextcloud-calendar — Tims Kalender via CalDAV

Tims Kalender ist Nextcloud, **nicht** Google. Bei jedem Kalender-Trigger sofort hier her, nicht ins Tool-Listing schauen.

## Endpoints + Auth

**Privat** (`cloud.timrudorf.de`):
- Base: `${NC_PRIVATE_HOST}/remote.php/dav/calendars/${NC_PRIVATE_USER}/`
- Auth: Basic, `$NC_PRIVATE_USER` / `$NC_PRIVATE_PASSWORD`

**Dienstlich** (EDP):
- Base: `${NC_WORK_HOST}/remote.php/dav/calendars/${NC_WORK_USER}/`
- Auth: Basic, `$NC_WORK_USER` / `$NC_WORK_PASSWORD`

Welcher Kontext gilt → siehe `CONTEXTS.md`. Im Zweifel: **privat** (Sport, Familie, Studium, Rettungsdienst sind alle privat).

## Kalender (privat)

| Pfad | Wofür |
|---|---|
| `personal/` | Persönlich — Familie, Reisen, **Sport**, Alltag |
| `studium/` | Uni-Termine |
| `rettungsdienst/` | Schichten Rettungsdienst |
| `app-generated--deck--board-1/` | Nextcloud Deck — ignorieren |

Bei Sport-Terminen ist `personal/` der richtige Kalender.

## Workflow

```bash
# 1) Env laden falls Subshell — die NC_*-Vars sind schon im Container-Env.
#    Falls leer:
set -a; source /workspace/docker-compose/jarvis/.env 2>/dev/null || true; set +a
```

### Lesen — Termine in einem Zeitfenster

```bash
START="20260420T000000Z"   # ISO basic UTC
END="20260510T235959Z"

curl -s -u "$NC_PRIVATE_USER:$NC_PRIVATE_PASSWORD" \
  -X REPORT "${NC_PRIVATE_HOST}/remote.php/dav/calendars/${NC_PRIVATE_USER}/personal/" \
  -H "Depth: 1" -H "Content-Type: application/xml" \
  --data "<?xml version=\"1.0\"?>
<c:calendar-query xmlns:d=\"DAV:\" xmlns:c=\"urn:ietf:params:xml:ns:caldav\">
  <d:prop><d:getetag/><c:calendar-data/></d:prop>
  <c:filter>
    <c:comp-filter name=\"VCALENDAR\">
      <c:comp-filter name=\"VEVENT\">
        <c:time-range start=\"$START\" end=\"$END\"/>
      </c:comp-filter>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>"
```

Antwort ist Multistatus-XML mit `<d:href>` (= relativer Pfad zum Event = Identifier für Update/Delete) und `<cal:calendar-data>` (= rohes VCALENDAR/VEVENT iCal). Mit `xmllint --xpath` oder Python (`vobject`/`icalendar`) parsen.

### Suchen — alle Events mit Text-Match (z.B. „Tilman" → korrigieren auf „Tillmann")

CalDAV `text-match`:

```bash
curl -s -u "$NC_PRIVATE_USER:$NC_PRIVATE_PASSWORD" \
  -X REPORT "${NC_PRIVATE_HOST}/remote.php/dav/calendars/${NC_PRIVATE_USER}/personal/" \
  -H "Depth: 1" -H "Content-Type: application/xml" \
  --data '<?xml version="1.0"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><d:getetag/><c:calendar-data/></d:prop>
  <c:filter>
    <c:comp-filter name="VCALENDAR">
      <c:comp-filter name="VEVENT">
        <c:prop-filter name="SUMMARY">
          <c:text-match collation="i;unicode-casemap">Tilman</c:text-match>
        </c:prop-filter>
      </c:comp-filter>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>'
```

Achtung: `text-match` matcht nur **eine** Property pro Filter. Für „Tilman ODER Tilmann ODER Tillman" → entweder mehrere Queries oder breit lesen + lokal mit Regex filtern.

### Anlegen — neuer Termin

```bash
UID=$(uuidgen)
SUMMARY="Gym mit Tillmann"
DTSTART="20260504T190000"   # lokal, mit TZID
DTEND="20260504T210000"
LOCATION="Fitness First Konstablerwache, Zeil 72-82, 60313 Frankfurt am Main"

cat > /tmp/event.ics <<EOF
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//jarvis//nextcloud-calendar//DE
BEGIN:VEVENT
UID:${UID}
DTSTAMP:$(date -u +%Y%m%dT%H%M%SZ)
SUMMARY:${SUMMARY}
LOCATION:${LOCATION}
DTSTART;TZID=Europe/Berlin:${DTSTART}
DTEND;TZID=Europe/Berlin:${DTEND}
END:VEVENT
END:VCALENDAR
EOF

curl -s -u "$NC_PRIVATE_USER:$NC_PRIVATE_PASSWORD" \
  -X PUT "${NC_PRIVATE_HOST}/remote.php/dav/calendars/${NC_PRIVATE_USER}/personal/${UID}.ics" \
  -H "Content-Type: text/calendar; charset=utf-8" \
  --data-binary @/tmp/event.ics
```

Antwort 201 = angelegt, 204 = ersetzt.

### Ändern — bestehenden Termin updaten

1. Mit `calendar-query` (oben) das Event holen.
2. `<d:href>` merken (= absolute Pfad, z.B. `/remote.php/dav/calendars/tim/personal/abc-123.ics`).
3. Roh-iCal aus `<cal:calendar-data>` lokal patchen (z.B. `sed`/`python` für Title-Korrektur).
4. Per `PUT` an die ursprüngliche `<d:href>` zurückschreiben. **Wichtig**: `If-Match` mit dem zuvor gelesenen `getetag` setzen, damit kein Concurrent-Edit durchrutscht.

```bash
HREF="/remote.php/dav/calendars/tim/personal/abc-123.ics"
ETAG='"a1b2c3"'   # genau so wie aus getetag, mit Quotes

curl -s -u "$NC_PRIVATE_USER:$NC_PRIVATE_PASSWORD" \
  -X PUT "${NC_PRIVATE_HOST}${HREF}" \
  -H "Content-Type: text/calendar; charset=utf-8" \
  -H "If-Match: ${ETAG}" \
  --data-binary @/tmp/event-patched.ics
```

Bei Massen-Updates (z.B. Tillmann-Schreibweise über alle Sport-Termine): batch-loop, jede Iteration einzeln. Bei 412 (etag mismatch) → Event neu fetchen, neu patchen, retry.

### Löschen

```bash
curl -s -u "$NC_PRIVATE_USER:$NC_PRIVATE_PASSWORD" \
  -X DELETE "${NC_PRIVATE_HOST}${HREF}" \
  -H "If-Match: ${ETAG}"
```

204 = gelöscht.

## Schreib-Konventionen

- **Location bei fixen Orten immer mitgeben** — Tim hat das explizit so gewünscht (`tim/feedback/kalender-location.md`):
  - Mo/Mi Gym mit Tillmann → *Fitness First Frankfurt Konstablerwache, Zeil 72-82, 60313 Frankfurt am Main*
  - Do Intervalle mit Tillmann → *Laufbahn Ostendpark, Frankfurt am Main*
- **Zeitzone**: `Europe/Berlin` mit `TZID=`. Keine UTC-Offsets ausrechnen.
- **Titel kompakt** — ~50 Zeichen, Apple Calendar zeigt nur das.
- **Schreibweise Tillmann**: zwei L, zwei N. Häufiger Fehler: „Tilman", „Tillman", „Tilmann". Beim Eintragen prüfen.

## Approval

Tims Kalender ist sein eigenes System. **Keine Rückfrage**, einfach machen — auch bei Massen-Updates. Siehe `tim/feedback/eigenstaendigkeit.md`: Approval-Pflicht gilt nur für **Außenwirkung** (externe Kommunikation, shared/destructive, Kosten). Bulk-Edits, Bulk-Anlegen, Löschen einzelner Termine, Verschieben — alles ohne Rückfrage. Danach kurz berichten was gemacht wurde und warum.

## NIE TUN

- `mcp__claude_ai_Google_Calendar__*` aufrufen — gibt's bei Tim nicht, der Hook blockt das.
- Eigene HTTP-Endpoints raten oder Google-API-curls erfinden.
- DTSTART/DTEND ohne TZID schreiben.
- Verbose Reminder-Splits (Pomodoro-Schritte etc.) anlegen — siehe `tim/feedback/kalender-source-of-truth.md`.

## Folge-Upgrade (offen)

Eine Python-CLI `jc` analog zu `jarvis-tasks/jt` würde curl-XML-Hand-Patchen ersetzen. Wenn Tim das will — Pattern aus `/workspace/jarvis-tasks/jt.py` kopieren, `caldav` + `icalendar` libs nutzen, Subkommandos `list / search / add / update / delete / move`.

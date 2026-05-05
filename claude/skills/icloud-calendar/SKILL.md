---
name: icloud-calendar
description: Tims Kalender liegt auf iCloud (CalDAV mit App-spezifischem Passwort). Use this skill für jede Kalender-Operation — lesen, suchen, eintragen, ändern, löschen. NIEMALS Google Calendar MCP nutzen, auch wenn `mcp__claude_ai_Google_Calendar__*` als deferred tool gelistet ist (PreToolUse-Hook blockt das hart). Trigger keywords - kalender, termin, eintragen, "schau in meinen kalender", "wann ist", "trag … ein", "verschiebe", "lösche termin", "was steht am … an".
---

# icloud-calendar — Tims Kalender via iCloud-CalDAV

Tims Kalender ist iCloud, **nicht** Google, **nicht** Nextcloud. Bei jedem Kalender-Trigger sofort hier her, nicht ins Tool-Listing schauen.

## Endpoint + Auth

- **Base:** `https://caldav.icloud.com/`
- **Auth:** Basic, `$APPLE_ID` / `$APPLE_PASS` (App-spezifisches Passwort, dasselbe wie für Mail-IMAP)
- Apple redirected die Calls intern auf einen Shard wie `p123-caldav.icloud.com`. Bei direktem `curl` taucht der Shard in der `calendar-home-set`-Antwort auf — den dann für PUTs/DELETEs nutzen. Die Python-`caldav`-Lib macht das transparent.

## Kalender (Tims Account)

| Display-Name (iCloud) | Wofür | Schreibbar? |
|---|---|---|
| `Privat` | Persönlich — Familie, Reisen, **Sport**, Alltag | ja |
| `Studium` | Uni-Termine, Lernblöcke | ja |
| `EifertSystemsGmbH` | EDP-Werkstudent-Soft-Blocks (jarvis-generiert), keine echten Outlook-Termine | ja |
| `Rettungsdienst` | Schichten Rettungsdienst | ja |
| `Erinnerungen` | VTODO — ignorieren (für Kalender-Operationen) | – |
| `Rheingau, Events und Co` | Subscribed | nein |

**Kontext-Routing:** Im Zweifel **Privat** (Sport, Familie, Alltag). Uni-Lernblöcke und Pflichttermine → `Studium`. Werkstudent-Arbeitsblocks → `EifertSystemsGmbH`. Echte dienstliche Termine (Jourfix, Entwicklermeeting, Kunden-Meetings) kommen read-only aus dem Outlook-ICS-Feed (`WORK_CAL_ICS`, siehe `referenz/calendar-arbeit-ics.md`) — die **nicht** in iCloud-EifertSystemsGmbH duplizieren, sonst Doublette mit ICS.

## Workflow

Empfehlung: für non-trivialen Code die Python-`caldav`-Library nutzen — robuster als curl-XML zu basteln. Im jarvis-tasks-Venv schon installiert (`/workspace/jarvis-tasks/.venv/bin/python` (Container) bzw. analoges venv auf dem Mac).

```python
import caldav, os
client = caldav.DAVClient(
    url='https://caldav.icloud.com/',
    username=os.environ['APPLE_ID'],
    password=os.environ['APPLE_PASS'],
)
principal = client.principal()
cals = {c.get_display_name(): c for c in principal.calendars()}
privat = cals['Privat']
```

Für Quick-Curls — direkt gegen den iCloud-Shard, sobald discovered:

```bash
ICLOUD_USER=622364018   # Tims iCloud-User-ID, einmal per PROPFIND auf https://caldav.icloud.com/ ermittelt
ICLOUD_BASE="https://p123-caldav.icloud.com:443/${ICLOUD_USER}/calendars"
```

### Kalender enumerieren

```bash
curl -s -u "$APPLE_ID:$APPLE_PASS" \
  -X PROPFIND "${ICLOUD_BASE}/" \
  -H "Depth: 1" -H "Content-Type: application/xml" \
  --data '<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop>
    <d:displayname/>
    <d:resourcetype/>
    <c:supported-calendar-component-set/>
  </d:prop>
</d:propfind>'
```

### Lesen — Termine in einem Zeitfenster

UUID des Privat-Kalenders einmal aus der Enumeration merken (für Tim aktuell `F913DE90-E46A-48C0-A2B0-A402BD2DB9E6`, kann nach iCloud-Reset abweichen).

```bash
START="20260420T000000Z"
END="20260510T235959Z"

curl -s -u "$APPLE_ID:$APPLE_PASS" \
  -X REPORT "${ICLOUD_BASE}/F913DE90-E46A-48C0-A2B0-A402BD2DB9E6/" \
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

Antwort ist Multistatus-XML. Mit Python (`icalendar`) oder `xmllint` parsen.

### Anlegen — neuer Termin

```bash
EVENT_UID=$(uuidgen)
SUMMARY="Gym mit Tillmann"
DTSTART="20260504T190000"
DTEND="20260504T210000"
LOCATION="Fitness First Konstablerwache, Zeil 72-82, 60313 Frankfurt am Main"

cat > /tmp/event.ics <<EOF
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//jarvis//icloud-calendar//DE
BEGIN:VEVENT
UID:${EVENT_UID}
DTSTAMP:$(date -u +%Y%m%dT%H%M%SZ)
SUMMARY:${SUMMARY}
LOCATION:${LOCATION}
DTSTART;TZID=Europe/Berlin:${DTSTART}
DTEND;TZID=Europe/Berlin:${DTEND}
END:VEVENT
END:VCALENDAR
EOF

curl -s -u "$APPLE_ID:$APPLE_PASS" \
  -X PUT "${ICLOUD_BASE}/F913DE90-E46A-48C0-A2B0-A402BD2DB9E6/${EVENT_UID}.ics" \
  -H "Content-Type: text/calendar; charset=utf-8" \
  --data-binary @/tmp/event.ics
```

201 = neu, 204 = ersetzt. **Fallstrick zsh:** Variable `UID` ist read-only — anderen Namen verwenden.

### Ändern — bestehenden Termin updaten

1. `calendar-query` mit `text-match` auf SUMMARY/UID holen.
2. `<d:href>` und `<d:getetag>` merken.
3. iCal aus `<cal:calendar-data>` lokal patchen.
4. PUT auf den `<d:href>` mit `If-Match: <etag>`.

```bash
HREF="/622364018/calendars/F913DE90-.../<UID>.ics"
ETAG='"a1b2c3"'

curl -s -u "$APPLE_ID:$APPLE_PASS" \
  -X PUT "https://p123-caldav.icloud.com:443${HREF}" \
  -H "Content-Type: text/calendar; charset=utf-8" \
  -H "If-Match: ${ETAG}" \
  --data-binary @/tmp/event-patched.ics
```

### Löschen

```bash
curl -s -u "$APPLE_ID:$APPLE_PASS" -X DELETE "https://p123-caldav.icloud.com:443${HREF}"
```

204 = gelöscht.

## Schreib-Konventionen

- **Location bei fixen Orten immer mitgeben** (siehe `tim/feedback/kalender-location.md`):
  - Mo/Mi Gym mit Tillmann → *Fitness First Frankfurt Konstablerwache, Zeil 72-82, 60313 Frankfurt am Main*
  - Do Intervalle mit Tillmann → *Laufbahn Ostendpark, Frankfurt am Main*
- **Zeitzone:** `Europe/Berlin` mit `TZID=`. Keine UTC-Offsets ausrechnen.
- **Titel kompakt** — ~50 Zeichen, Apple Calendar zeigt nur das.
- **Schreibweise Tillmann:** zwei L, zwei N. Häufiger Whisper-Fehler.

## Einladungen + RSVPs

iCloud verschickt iMIP-Einladungen **selbst** (zu anderen Apple-Usern als native Kalender-Push, sonst per Mail-Anhang) sobald ein Event mit ATTENDEE/ORGANIZER liegt. RSVPs kommen automatisch zurück und reflektieren in den PARTSTAT der ATTENDEE-Properties. Das ist der Hauptgrund, warum Tim von Nextcloud weg ist — funktioniert dort nicht.

**Achtung beim Schreiben:** ATTENDEE/ORGANIZER nur dann setzen, wenn Tim **selbst** der ORGANIZER ist (sein Apple-ID-Email = `tim.rudorf@icloud.com`). Wenn Tim nur Teilnehmer eines fremden Events ist, gehört das Event nicht von außen via PUT in den Kalender — solche Events kommen automatisch via iMIP-Inbox + Annahme rein.

## Approval

Tims Kalender ist sein eigenes System. **Keine Rückfrage**, einfach machen — auch bei Massen-Updates. Siehe `tim/feedback/eigenstaendigkeit.md`. Approval-Pflicht gilt nur für **Außenwirkung** (externe Kommunikation, shared/destructive, Kosten).

## NIE TUN

- `mcp__claude_ai_Google_Calendar__*` aufrufen — gibt's bei Tim nicht, der Hook blockt das.
- Auf Nextcloud-Calendars zugreifen — die wurden 2026-05-05 komplett gelöscht, alle Termine sind in iCloud.
- DTSTART/DTEND ohne TZID schreiben.
- ATTENDEE/ORGANIZER mit fremden Principal-Pfaden (`/aXX...principal/`) per PUT durchschleifen — iCloud lehnt mit 412 ab. Bei Migrations-/Rekonstruktions-Szenarien diese Properties strippen oder Event mit frischer UID neu anlegen.
- Verbose Reminder-Splits (Pomodoro-Schritte etc.) anlegen — siehe `tim/feedback/kalender-source-of-truth.md`.

## zsh-Fallstrick

`UID` ist in zsh eine read-only Integer-Variable. Wenn du shell-scriptest:

```bash
EVENT_UID=$(uuidgen)   # statt UID=$(uuidgen)
```

Sonst: `bad math expression: operator expected`.

## Folge-Upgrade (offen)

Eine Python-CLI `jc` analog zu `jarvis-tasks/jt` würde curl-XML-Hand-Patchen ersetzen. Pattern: `caldav` + `icalendar` libs, Subkommandos `list / search / add / update / delete / move`.

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

## Vor jedem Schreibvorgang — Konflikt + Duplikat prüfen

Bevor ein neues Event ins iCloud geschrieben wird (und auch bevor verschoben wird), **immer erst lesen**:

1. Über alle relevanten iCloud-Kalender (`Privat`, `Studium`, `EifertSystemsGmbH`) am gleichen Tag(en) suchen — `cal.search(start, end, event=True, expand=True)` — plus Outlook-ICS via `WORK_CAL_ICS` (siehe [[referenz/calendar-arbeit-ics]]).
2. **Duplikat?** (gleiche Person/Thema im SUMMARY oder überlappendes Zeitfenster ±15 min oder gleicher externer Identifier wie Zoom-Meeting-ID): das **bestehende Event updaten** (`event_by_url(...)`, `ev.data = neue_ical`, `ev.save()`) — UID beibehalten. **Niemals** ein paralleles zweites Event anlegen.
3. **Konflikt mit anderem Termin?** Kleinere Bewegungen (Lernblock kürzen, Soft-Anker schieben) selbst lösen + per `notify_user` informieren ([[tim/feedback/planer-eigenstaendig]]). Bei Pflicht-Konflikt oder Unklarheit: `request_approval` mit Konflikt-Beschreibung.
4. **Soft-Anker** (🌅 Aufstehen, 🌙 Bett, 📚 Lernblock, 🍽 Mittag) zählen nicht als Konflikt — sie sind erwartet.

Volle Begründung: [[tim/feedback/kalender-konflikt-und-duplikate-pruefen]].

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

## Apple-Maps-Verknüpfung im Termin (`X-APPLE-STRUCTURED-LOCATION`)

Damit Apple Calendar **eine Karte unter dem Termin anzeigt** und der Tap auf die Adresse direkt nach Apple Maps führt, reicht das normale `LOCATION`-Feld nicht — es braucht zusätzlich die proprietäre `X-APPLE-STRUCTURED-LOCATION`-Property mit Geo-Koordinaten als `geo:lat,lng`-URI.

**Minimum-Form (ohne MapKit-Handle, funktioniert von außen):**

```
X-APPLE-STRUCTURED-LOCATION;VALUE=URI;X-APPLE-RADIUS=70;X-APPLE-REFERENCEFRAME=1;X-TITLE="Name\nStraße Hausnummer, PLZ Ort":geo:50.126970,8.685191
```

- `geo:lat,lng` — Pflicht, sonst wird's ignoriert
- `X-TITLE` — was Apple Maps als Pin-Beschriftung zeigt (mit `\n` für Zeilenumbruch im Display)
- `X-APPLE-RADIUS` — Such-Radius in Metern (50–100 sinnvoll für Restaurants/Studios)
- `X-APPLE-REFERENCEFRAME=1` — extern erzeugt (0 wäre Apple's MapKit-Quelle)
- `X-APPLE-MAPKIT-HANDLE` — Apple-internes Place-Token (Base64-Protobuf), kann nur Apple's MapKit-API generieren. Von außen weglassen — Apple Maps macht beim ersten Öffnen Reverse-Geocoding und ergänzt das Handle selbst.

**RFC-5545-Line-Folding ist kritisch.** iCal-Zeilen >75 Octets müssen mit `\r\n ` (CRLF + Leerzeichen) gefaltet werden — sonst bricht Apples Parser komplett, normalisiert die Adresse zu Großbuchstaben und merged das XAL-Property in die LOCATION-TEXT-Wert (Empirisch 2026-05-06 verifiziert: ein 700-Zeichen-XAL ohne Folding zerstört das VEVENT). **Bei jedem PUT von LOCATION oder X-APPLE-STRUCTURED-LOCATION** diesen Helper nutzen:

```python
def fold(line: str) -> str:
    """RFC 5545 Section 3.1: fold lines >75 octets with CRLF + space."""
    b = line.encode('utf-8')
    if len(b) <= 75:
        return line
    chunks = [b[:75].decode('utf-8')]
    rest = b[75:]
    while len(rest) > 74:
        chunks.append(' ' + rest[:74].decode('utf-8'))
        rest = rest[74:]
    if rest:
        chunks.append(' ' + rest.decode('utf-8'))
    return '\r\n'.join(chunks)
```

Beim Umbau bestehender Events: VEVENT-Block kpl. neu zusammensetzen statt Zeilen einzufügen — dann kommt Folding garantiert auf alle relevanten Properties.

**Geocoding** (lat/lng besorgen):

```bash
# Nominatim (OSM) — strukturiert mit Hausnummer
curl -s "https://nominatim.openstreetmap.org/search?street=Eckenheimer+Landstra%C3%9Fe+111&city=Frankfurt&postalcode=60318&format=json&limit=1" \
  -H "User-Agent: jarvis/1.0"
```

OSM hat oft nicht jede Hausnummer erfasst — bei Lücken die Nachbarn (109, 113) abfragen und mitteln. Apple ist tolerant: Ungenauigkeit von ~30m wird beim Open-in-Maps korrigiert (Apple macht selbst Reverse-Geocoding auf die volle Adresse).

**Stamm-Locations mit Geo-Koordinaten** (vorab bekannt, kein Lookup nötig). Für jede Stamm-Location ist sowohl die `LOCATION`-Schreibweise (im Format wie Apple Maps sie speichert — wichtig, sonst greift das MAPKIT-HANDLE nicht) als auch das vollständige `X-APPLE-STRUCTURED-LOCATION`-Snippet erfasst. **Beim Anlegen oder Updaten von Sport-/Stamm-Terminen immer beides aus dieser Tabelle übernehmen** — sonst sieht Tim die Apple-Maps-Karte nicht im Termin.

**Konstablerwache** — Tims **Default-Studio** für alle Sport-Termine (PM-Tilli + AM-Schulter/Arme + Fr/Sa Solo OK/UK), sofern nichts anderes angesagt:

```ical
LOCATION:Fitness First Frankfurt - Konstablerwache\nZeil 72\, 60313 Frank
 furt\, Germany
X-APPLE-STRUCTURED-LOCATION;VALUE=URI;X-APPLE-MAPKIT-HANDLE=CAESxAIIrk0Qm
 oig4L24v7TpARoSCfGcLSC0DklAEQJQewBBXyFAIl8KB0dlcm1hbnkSAkRFGgVIZXNzZSoJR
 nJhbmtmdXJ0MglGcmFua2Z1cnQ6BTYwMzEzQgxJbm5lbnN0YWR0IElSBFplaWxaAjcyYgdaZ
 WlsIDcyigEKSW5uZW5zdGFkdCopRml0bmVzcyBGaXJzdCBGcmFua2Z1cnQgLSBLb25zdGFib
 GVyd2FjaGUyB1plaWwgNzIyDzYwMzEzIEZyYW5rZnVydDIHR2VybWFueTgvUAFabQooCJqIo
 OC9uL+06QESEgnxnC0gtA5JQBECUHsAQV8hQBiuTZADAZgDAaIfQAiaiKDgvbi/tOkBGjMKK
 UZpdG5lc3MgRmlyc3QgRnJhbmtmdXJ0IC0gS29uc3RhYmxlcndhY2hlEAAqAmVuQAA=;X-AP
 PLE-RADIUS=141.1750793457031;X-APPLE-REFERENCEFRAME=0;X-TITLE="Fitness F
 irst Frankfurt - Konstablerwache\nZeil 72, 60313 Frankfurt, Germany":geo
 :50.114872,8.686043
```

Verifiziert per direkter Apple-Calendar-Eintragung 2026-05-06 (UID `c6fabf51-…`). MAPKIT-HANDLE und REFERENCEFRAME=0 funktionieren bei Re-PUT — Apple respektiert das.

**FFC Olympia 07** — Tims Default für **Do PM Intervalle mit Tillmann** (Sportclub Olympia 1906 / FFC Olympia 07, Laufbahn am Ostpark):

```ical
LOCATION:FFC Olympia 07\nRatsweg 10\, 60386 Frankfurt\, Germany
X-APPLE-STRUCTURED-LOCATION;VALUE=URI;X-APPLE-MAPKIT-HANDLE=CAESogIIrk0Q2
 YGf8LHjoc3hARoSCfxUFRqID0lAEc9IKY09dCFAIlwKB0dlcm1hbnkSAkRFGgVIZXNzZSoJR
 nJhbmtmdXJ0MglGcmFua2Z1cnQ6BTYwMzg2QgNPc3RSB1JhdHN3ZWdaAjEwYgpSYXRzd2VnI
 DEwigEKUmllZGVyd2FsZCoORkZDIE9seW1waWEgMDcyClJhdHN3ZWcgMTAyDzYwMzg2IEZyY
 W5rZnVydDIHR2VybWFueTgvUAFaZgo8CNmBn/Cx46HN4QESEgn8VBUaiA9JQBHPSCmNPXQhQ
 BiuTZADAZgDAaIDEUlFMTlBODcxQjFFMDdDMEQ5oh8lCNmBn/Cx46HN4QEaGAoORkZDIE9se
 W1waWEgMDcQACoCZGVAAA==;X-APPLE-RADIUS=206.2665481143097;X-APPLE-REFEREN
 CEFRAME=1;X-TITLE="FFC Olympia 07\nRatsweg 10, 60386 Frankfurt, Germany"
 :geo:50.121341,8.727032
```

Tim sagte umgangssprachlich "Laufbahn Ostendpark" / "Olympia im Ostpark" — der offizielle Name ist FFC Olympia 07 / Sport-Club Olympia 1906 e.V., Adresse Ratsweg 10 (Stadtteil Riederwald, am Ostpark). Verifiziert per Apple-Calendar-Eintragung 2026-05-05 (UID `e7441fbc-…`).

**Friedberger Platz** — Tims Default für **Di PM Long Run mit Tillmann** (Treffpunkt am Friedberger Platz):

```ical
LOCATION:Friedberger Platz\nFrankfurt\, Hesse\, Germany
X-APPLE-STRUCTURED-LOCATION;VALUE=URI;X-ADDRESS="Frankfurt, Hesse, German
 y";X-APPLE-MAPKIT-HANDLE=CAEScBoSCYEniBXJD0lAEWNYamImYiFAIioKB0dlcm1hbnk
 SAkRFGgVIZXNzZSoJRnJhbmtmdXJ0MglGcmFua2Z1cnQqEUZyaWVkYmVyZ2VyIFBsYXR6Mgl
 GcmFua2Z1cnQyBUhlc3NlMgdHZXJtYW55UAE=;X-APPLE-RADIUS=0;X-APPLE-REFERENCE
 FRAME=0;X-TITLE=Friedberger Platz:geo:50.123324,8.691699
```

Verifiziert per Apple-Calendar-Eintragung 2026-05-05 (UID `807623f5-…`). Achtung: `X-APPLE-RADIUS=0` und kein expliziter Stadtbezug im LOCATION — Treffpunkt ist groß genug, dass Apple Maps den ohne Radius findet.

**SKW-Bib (Sprach- und Kulturwissenschaften, Campus Westend)** — Tims **Default-Location für ALLE jarvis-generierten Lernblöcke** (`📚 Lernblock`, `🧠 Anki`). Tim lernt prinzipiell in der SKW-Bib am Goethe-Uni-FB09. Override nur bei Pflichtterminen mit eigener Location (z.B. TUD Darmstadt):

```ical
LOCATION:Sprach- und Kulturwissenschaften (SKW)\nWismarer Straße 4\, 6032
 3 Frankfurt\, Germany
X-APPLE-STRUCTURED-LOCATION;VALUE=URI;X-APPLE-MAPKIT-HANDLE=CAES9gIIrk0Qs
 czKqoj0iOi3ARoSCbdtznemEElAERJhDWFGViFAIngKB0dlcm1hbnkSAkRFGgVIZXNzZSoJR
 nJhbmtmdXJ0MglGcmFua2Z1cnQ6BTYwMzIzQg1Jbm5lbnN0YWR0IElJUhBXaXNtYXJlciBTd
 HJhw59lWgE0YhJXaXNtYXJlciBTdHJhw59lIDSKAQxXZXN0ZW5kLU5vcmQqJlNwcmFjaC0gd
 W5kIEt1bHR1cndpc3NlbnNjaGFmdGVuIChTS1cpMhJXaXNtYXJlciBTdHJhw59lIDQyDzYwM
 zIzIEZyYW5rZnVydDIHR2VybWFueTgvUAFafgo8CLHMyqqI9IjotwESEgm3bc53phBJQBESY
 Q1hRlYhQBiuTZADAZgDAaIDEUlCN0QwMjNBMDg1NTJBNjMxoh89CLHMyqqI9IjotwEaMAomU
 3ByYWNoLSB1bmQgS3VsdHVyd2lzc2Vuc2NoYWZ0ZW4gKFNLVykQACoCZGVAAA==;X-APPLE-
 RADIUS=158.4766694912;X-APPLE-REFERENCEFRAME=0;X-TITLE="Sprach- und Kult
 urwissenschaften (SKW)\nWismarer Straße 4, 60323 Frankfurt, Germany":geo
 :50.130080,8.668506
```

Verifiziert per Apple-Calendar-Eintragung 2026-05-27 (Tim selbst für KW22-Uni-Fokus-Lernblöcke, UID `A9A91E91-…`). MAPKIT-HANDLE direkt aus Apples Quelle übernommen. Beim Anlegen JEDES 📚 Lernblock / 🧠 Anki-Floor → diesen Block 1:1 verwenden, sofern nicht der Block selbst ein eigenes `location`-Override mitbringt. Siehe [[tim/feedback/kalender-location-skw]].

**Andere Stamm-Locations:**

| Location | Geo | LOCATION (Apple-Schreibweise) |
|---|---|---|
| Fitness First MyZeil | `50.114945,8.681096` | `Fitness First Frankfurt - MyZeil\nZeil 102\, Haus 106\, 60313 Frankfurt am Main\, Deutschland` (verifiziert per Apple, MAPKIT-HANDLE bekannt — siehe Eventquelle UID `c6fabf51` Stand vor Korrektur) |
| Herkerts Bistro Eckenheimer | `50.126970,8.685191` | `Herkert\nEckenheimer Landstraße 111\, 60318 Frankfurt am Main\, Deutschland` (verifiziert, MAPKIT-HANDLE im Event 2026-05-06 12:00 Mittag) |
| Herkert Feinkost Oeder Weg | (TBD) | `Herkert, Oeder Weg 50, 60318 Frankfurt am Main` |
| Cafeteria Hoagosch (SKW-Bib) | `50.130080,8.668506` | `Cafeteria Hoagosch\nWismarer Straße 4\, 60323 Frankfurt\, Germany` — Tims **Default-Mittag-Uni** wenn vor Mittag bereits in der SKW-Bib. Geo identisch mit SKW-Gebäude. MAPKIT-HANDLE TBD (Tim bitte einmal in Apple Maps "Hoagosch" tippen, Termin händisch anlegen, dann übernehmen wir den Handle). Fallback: extern-Format mit REFERENCEFRAME=1, X-RADIUS=70, ohne Handle — Apple Maps reverse-geocoded beim Open. |

Für neue Stamm-Locations: Adresse verifizieren (siehe `tim/feedback/kalender-location.md`) → **am liebsten** Tim einmal in Apple Calendar händisch eintragen lassen (MAPKIT-HANDLE = beste Maps-Integration), dann Event-Body lesen und hier ablegen. Fallback: Nominatim geocoden + extern-Format (`REFERENCEFRAME=1`, ohne MAPKIT-HANDLE).

**Beispiel-Event mit Apple-Maps-Karte + Attendee:**

```
BEGIN:VEVENT
UID:...
SUMMARY:🍽 Mittag mit Tillmann @ Herkerts Bistro
LOCATION:Herkerts Bistro\, Eckenheimer Landstraße 111\, 60318 Frankfurt am Main
DTSTART;TZID=Europe/Berlin:20260506T120000
DTEND;TZID=Europe/Berlin:20260506T133000
X-APPLE-STRUCTURED-LOCATION;VALUE=URI;X-APPLE-RADIUS=70;X-APPLE-REFERENCEFRAME=1;X-TITLE="Herkerts Bistro\nEckenheimer Landstraße 111, 60318 Frankfurt am Main":geo:50.126970,8.685191
ORGANIZER;CN=Tim Rudorf:mailto:tim.rudorf@icloud.com
ATTENDEE;CN=Tillmann Scherer;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:scherer.tillmann@web.de
END:VEVENT
```

## Schreib-Konventionen

- **Location bei fixen Orten immer mitgeben** (siehe `tim/feedback/kalender-location.md`) — bei Studio-Sessions zusätzlich `X-APPLE-STRUCTURED-LOCATION` aus der Stamm-Tabelle setzen:
  - **Default für ALLE Sport-Studio-Termine** (Mo/Mi Gym Tilli, Di/Do AM Schulter/Arme, Fr/Sa Solo OK/UK): **Fitness First Konstablerwache** — Snippet aus Stamm-Tabelle. Tim sagt explizit Bescheid, wenn ein Ausnahme-Studio (MyZeil, Opernplatz, …) anliegt.
  - Do Intervalle mit Tillmann → *Laufbahn Ostendpark, Frankfurt am Main*
- **Zeitzone:** `Europe/Berlin` mit `TZID=`. Keine UTC-Offsets ausrechnen.
- **Titel kompakt** — ~50 Zeichen, Apple Calendar zeigt nur das.
- **Schreibweise Tillmann:** zwei L, zwei N. Häufiger Whisper-Fehler.

## Einladungen + RSVPs

iCloud verschickt iMIP-Einladungen **selbst** (zu anderen Apple-Usern als native Kalender-Push, sonst per Mail-Anhang) sobald ein Event mit ATTENDEE/ORGANIZER liegt. RSVPs kommen automatisch zurück und reflektieren in den PARTSTAT der ATTENDEE-Properties. Das ist der Hauptgrund, warum Tim von Nextcloud weg ist — funktioniert dort nicht.

**Achtung beim Schreiben:** ATTENDEE/ORGANIZER nur dann setzen, wenn Tim **selbst** der ORGANIZER ist (sein Apple-ID-Email = `tim.rudorf@icloud.com`). Wenn Tim nur Teilnehmer eines fremden Events ist, gehört das Event nicht von außen via PUT in den Kalender — solche Events kommen automatisch via iMIP-Inbox + Annahme rein.

### Tilli-Sessions automatisch mit Attendee

Bei **allen gemeinsamen Sport-Sessions mit Tillmann** (Mo/Mi PM Gym, Di PM Long Run, Do PM Intervalle) Tilli direkt als ATTENDEE mit reinschreiben — Tim hat das so gewünscht (2026-05-06). iCloud schickt die Einladung dann automatisch raus, RSVPs syncen zurück. Format aus Tims selbst-eingetragenen Events:

```ical
ORGANIZER;CN=Tim Rudorf;EMAIL=tim@rudorf.me:mailto:tim@rudorf.me
ATTENDEE;CN=Tim Rudorf;CUTYPE=INDIVIDUAL;EMAIL=tim@rudorf.me;PARTSTAT=ACCEPTED;ROLE=CHAIR:mailto:tim@rudorf.me
ATTENDEE;CN=Tillmann Scherer;CUTYPE=INDIVIDUAL;EMAIL=scherer.tillmann@web.de:mailto:scherer.tillmann@web.de
```

Tims primärer Mail-Alias in iCloud-Kalender ist **`tim@rudorf.me`** (nicht `tim.rudorf@icloud.com`) — so taucht er in seinen eigenen ORGANIZER-Feldern auf. iCloud akzeptiert mailto-only Form — der `principal/`-Pfad ist optional und wird beim Sync ergänzt.

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

---
name: Tims Kalender liegt auf Nextcloud (privat)
description: Kalender-Lookup für Tim geht über CalDAV auf cloud.timrudorf.de — nicht über Google Calendar MCP
type: reference
originSessionId: 6da8ffce-ed73-4d31-92fe-c648997a3234
---
Tims **privater Kalender** ist auf seiner privaten Nextcloud-Instanz (`$NC_PRIVATE_HOST` = cloud.timrudorf.de). Der Google-Calendar-MCP-Connector ist nicht der richtige Weg — bei Anfragen wie "schau mal in meinen Kalender" / "wann ist X" / "was steht am Datum Y an" direkt CalDAV ansteuern.

**Endpoint:** `${NC_PRIVATE_HOST}/remote.php/dav/calendars/${NC_PRIVATE_USER}/`
**Auth:** Basic Auth mit `$NC_PRIVATE_USER` / `$NC_PRIVATE_PASSWORD`

**Bekannte Kalender:**
- `personal/` ("Persönlich") — privates Leben, Familie, Reisen, Sport-Termine
- `studium/` — Uni-Termine
- `rettungsdienst/` — Schichten/Termine Rettungsdienst
- `app-generated--deck--board-1/` — Nextcloud Deck (ignorieren)

**Such-Pattern (CalDAV REPORT, Zeitfenster):**
```bash
curl -s -u "$NC_PRIVATE_USER:$NC_PRIVATE_PASSWORD" \
  -X REPORT "${NC_PRIVATE_HOST}/remote.php/dav/calendars/${NC_PRIVATE_USER}/personal/" \
  -H "Depth: 1" -H "Content-Type: application/xml" \
  --data '<?xml version="1.0"?><c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:prop><c:calendar-data/></d:prop><c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VEVENT"><c:time-range start="YYYYMMDDT000000Z" end="YYYYMMDDT235959Z"/></c:comp-filter></c:comp-filter></c:filter></c:calendar-query>'
```

**Dienstliche Termine** (EDP, Werkstudent) liegen analog auf `$NC_WORK_HOST` — dort wenn der Kontext beruflich ist.

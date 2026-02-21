---
name: edp-share
description: This skill should be used when the user asks to "share files with a customer", "upload to Sharecloud", "Dateien bereitstellen", "send files to customer", "Nextcloud upload", or uses /edp-share. It uploads files to the Nextcloud Sharecloud and notifies the customer via Zammad.
argument-hint: [ticket-number | customer-name] [file-path...] [context]
---

# EDP Sharecloud — Dateien für Kunden bereitstellen

Lädt Dateien in die Nextcloud-basierte Sharecloud (`einsatzleitsoftware.de/nextcloud`) hoch und benachrichtigt den Kunden per Zammad-Ticket.

## Configuration

Environment variables from `~/Develop/EDP/.env`:

```
NC_HOST=https://einsatzleitsoftware.de/nextcloud
NC_WEBDAV=/remote.php/dav/files/tim.rudorf
NC_USER=tim.rudorf
NC_PASSWORD=...
ZAMMAD_HOST=...
ZAMMAD_TOKEN=...
```

## Workflow

### Schritt 1: Argumente parsen

Aus den Argumenten extrahieren:
- **Ticket oder Kunde**: Zammad-Ticketnummer ODER Kundenname/Organisation
- **Dateipfad(e)**: Ein oder mehrere lokale Dateien
- **Kontext** (optional): Anlass / Beschreibung (z.B. "Setup-Dateien", "Testlizenz")

### Schritt 2: Kundeninformationen beschaffen

**Bei Ticketnummer** → `/zammad-read` nutzen → Organisation aus dem Ticket extrahieren.

**Bei Kundenname** → Zammad-API durchsuchen:

```bash
source ~/Develop/EDP/.env
BASE="${ZAMMAD_HOST%/}"

curl -s -H "Authorization: Token token=${ZAMMAD_TOKEN}" \
  "$BASE/api/v1/organizations/search?query={name}&limit=5" > /tmp/z_org_search.json \
  && jq '[.[] | {id, name, note}]' /tmp/z_org_search.json
```

Bei Unsicherheit (mehrere Treffer, kein Treffer) → User per `AskUserQuestion` fragen.

### Schritt 3: Nextcloud-Ordner prüfen

Ordnerliste unter `/Kunden/` laden:

```bash
source ~/Develop/EDP/.env

curl -s -u "$NC_USER:$NC_PASSWORD" \
  -X PROPFIND \
  -H "Depth: 1" \
  -H "Content-Type: application/xml" \
  -d '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:displayname/></d:prop></d:propfind>' \
  "$NC_HOST$NC_WEBDAV/Kunden/" > /tmp/nc_kunden.xml \
  && grep -oP '<d:displayname>\K[^<]+' /tmp/nc_kunden.xml | sort
```

**Fuzzy-Match** gegen den Organisationsnamen:
- Ordnernamen sind lowercase mit Bindestrichen und Prefixes (`fw-`, `drk-`, `lk-`, etc.)
- Vergleich: Organisation enthält Teile des Ordnernamens oder umgekehrt

**Match gefunden** → User per `AskUserQuestion` bestätigen lassen (Sicherheit!):
> Kunde "{organisation}" → Nextcloud-Ordner `{ordnername}` verwenden?

**Kein Match** → Weiter zu Schritt 4 (neuen Ordner erstellen).

### Schritt 4: Ordner erstellen (falls nötig)

Nur wenn kein passender Ordner gefunden wurde.

**4a: Ordner anlegen** via WebDAV MKCOL:

```bash
source ~/Develop/EDP/.env

ORDNER="{ordnername}"  # lowercase, Bindestriche, passender Prefix
curl -s -o /dev/null -w "%{http_code}" \
  -u "$NC_USER:$NC_PASSWORD" \
  -X MKCOL \
  "$NC_HOST$NC_WEBDAV/Kunden/$ORDNER/"
```

HTTP 201 = Erfolg. Den Ordnernamen mit bestehendem Namensschema konsistent wählen (User bestätigen lassen).

**4b: Public Link mit Passwort erstellen** via OCS Share API:

```bash
source ~/Develop/EDP/.env

PASSWORD=$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | head -c 12)
curl -s -u "$NC_USER:$NC_PASSWORD" \
  -X POST \
  -H "OCS-APIRequest: true" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "path=/Kunden/$ORDNER&shareType=3&permissions=1&password=$PASSWORD" \
  "$NC_HOST/ocs/v2.php/apps/files_sharing/api/v1/shares?format=json" > /tmp/nc_share.json \
  && jq '.ocs.data | {id, url, token}' /tmp/nc_share.json \
  && echo "PASSWORD: $PASSWORD"
```

- `shareType=3` = Public Link
- `permissions=1` = Read-Only

Link + Passwort für Schritt 7 merken.

### Schritt 5: Unterordner erstellen

Passend zum Anlass einen Unterordner erstellen (z.B. `Setup_2026-02`, `Testlizenz`, `Update_v4.5`):

```bash
source ~/Develop/EDP/.env

ORDNER="{ordnername}"
UNTERORDNER="{unterordner}"
curl -s -o /dev/null -w "%{http_code}" \
  -u "$NC_USER:$NC_PASSWORD" \
  -X MKCOL \
  "$NC_HOST$NC_WEBDAV/Kunden/$ORDNER/$UNTERORDNER/"
```

### Schritt 6: Dateien hochladen

Für jede Datei ein WebDAV PUT:

```bash
source ~/Develop/EDP/.env

ORDNER="{ordnername}"
UNTERORDNER="{unterordner}"
DATEI="{dateiname}"
curl -s -o /dev/null -w "%{http_code}" \
  -u "$NC_USER:$NC_PASSWORD" \
  -X PUT \
  --upload-file "{lokaler_pfad}" \
  "$NC_HOST$NC_WEBDAV/Kunden/$ORDNER/$UNTERORDNER/$DATEI"
```

HTTP 201 oder 204 = Erfolg. Bei mehreren Dateien einzeln hochladen und Ergebnis prüfen.

### Schritt 7: Kunden benachrichtigen

Per `/zammad-send`:

- **Bestehendes Ticket** → Ticketnummer als Argument an `/zammad-send`
- **Kein Ticket** → Kundenname als Argument an `/zammad-send` (Create-Modus)

Kontext für die Nachricht:
- Dateien liegen im SharePoint bereit
- Ggf. Link + Passwort nennen (bei neuem Ordner aus Schritt 4b)
- Unterordner-Name erwähnen
- Anlass aus dem User-Kontext

### Schritt 8: Ergebnis anzeigen

Nach Erfolg anzeigen:
- Hochgeladene Dateien + Nextcloud-Pfad
- Ticket-Nummer (neu oder bestehend)
- Ggf. Share-Link + Passwort (bei neuem Ordner)

## Bestehende Ordnerstruktur (Konventionen)

- ~80 Kundenordner mit Prefixes: `@-`, `bf-`, `brk-`, `drk-`, `fw-`, `ils-`, `lk-`, `lra-`, etc.
- Alles lowercase mit Bindestrichen
- Unterordner nach Anlass: `Bilddaten/`, `Testlizenz/`, `Daten_Altsystem/`, etc.

## Bestehende Freigaben prüfen

Falls unklar, ob ein Ordner bereits freigegeben ist:

```bash
source ~/Develop/EDP/.env

ORDNER="{ordnername}"
curl -s -u "$NC_USER:$NC_PASSWORD" \
  -H "OCS-APIRequest: true" \
  "$NC_HOST/ocs/v2.php/apps/files_sharing/api/v1/shares?path=/Kunden/$ORDNER&format=json" > /tmp/nc_shares.json \
  && jq '.ocs.data[] | {id, share_type, url, permissions, password_set: (.password != null)}' /tmp/nc_shares.json
```

## Notes

- **Jeder Bash-Aufruf ist eine eigene Shell** — `source ~/Develop/EDP/.env` in jedem Schritt.
- **Nextcloud-Passwort enthält Sonderzeichen** — immer in Anführungszeichen verwenden, `$NC_PASSWORD` nie unquoted.
- **WebDAV-URLs**: Immer `$NC_HOST$NC_WEBDAV/Kunden/...` für Dateioperationen.
- **OCS-API-URLs**: Immer `$NC_HOST/ocs/v2.php/apps/files_sharing/...` für Freigaben.
- **OCS-APIRequest Header**: Pflicht bei OCS-Endpunkten (`-H "OCS-APIRequest: true"`).
- Bei Fehlern: HTTP Status Code und Response Body anzeigen.

---

## Skill-Optimierung

Nach Abschluss dieses Skills kurz bewerten, ob Optimierungsbedarf besteht:

- **Empfehlung "ja"**: Fehler aufgetreten, Workarounds nötig, Befehle wiederholt, User-Korrekturen
- **Empfehlung "nein"**: Reibungsloser Lauf wie dokumentiert

Per `AskUserQuestion` fragen:

> Skill abgeschlossen. Soll die Skill-Dokumentation optimiert werden?
> Empfehlung: {ja — [kurzer Grund] | nein — Lauf war reibungslos}

Optionen: **"Ja, optimieren"**, **"Nein"**

Bei "Ja": `skill-optimize` mit Skill-Name `edp-share` ausführen.

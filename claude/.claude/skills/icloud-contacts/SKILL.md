---
name: icloud-contacts
description: Tims Adressbuch liegt auf iCloud (CardDAV mit App-spezifischem Passwort). Use this skill für Kontaktsuche, Telefonnummern-Lookup, E-Mail-Lookup, Kontakt-Details. Trigger keywords - "kontakt", "kontakte", "adressbuch", "telefonnummer", "telefonnummer von", "rufnummer", "mail-adresse von", "email von", "wer ist", "wie erreich ich", "such mal in den kontakten", "suche kontakt".
---

# icloud-contacts — iCloud CardDAV Lookup

Tims Adressbuch liegt auf iCloud unter `https://contacts.icloud.com/622364018/carddavhome/card/`. Auth: Basic mit `$APPLE_ID` / `$APPLE_PASS` (App-Specific Password — dasselbe wie für Mail-IMAP, Kalender und Reminders).

Aktuell ~700+ Kontakte im Default-Adressbuch.

## Tool

CLI: `/workspace/jarvis-contacts/ic` (alias `ic` falls im PATH).

```
ic search <query>          Substring-Match in Name/Org/Mail/Tel/Note → Trefferliste
ic show <uid|prefix>       Vollständige Daten eines Kontakts
ic list [--limit N]        Alphabetisch (FN), erste N Einträge
ic json [--query Q]        JSON aller (oder gematchten) Kontakte
ic count                   Anzahl Kontakte
ic --refresh <subcmd>      5-min-Cache umgehen
```

Vor jedem Aufruf: `set -a; source /opt/stacks/jarvis/.env; set +a` (für `APPLE_ID`/`APPLE_PASS`).

## Wann nutzen

- **Tim sagt** "such mal Tim Kohl in meinen Kontakten" → `ic search "Tim Kohl"`
- **Tim fragt** "Telefonnummer von Tilmann?" → `ic search Tilmann`, dann `ic show <uid-prefix>` für Details
- **Tim fragt** "wie ist die Mail-Adresse von Vogt?" → `ic search Vogt`
- **Lookup für andere Skills** — z.B. Mail an einen genannten Namen schicken: erst Kontakt suchen, dann Mail-Adresse extrahieren.

Bei mehrdeutigen Treffern (z.B. "Tim" → 14 Hits): Trefferliste in der UI anzeigen, Tim wählt den richtigen aus. Nicht raten welcher gemeint ist.

## Cache

`~/.cache/jarvis-contacts.json`, TTL 5 min. Reduziert die ~700-Roundtrip-PROPFIND+REPORT-Latenz auf ~50 ms für nachfolgende Queries. Wenn Tim einen frisch hinzugefügten Kontakt sucht und nicht findet: `ic --refresh search ...`.

## Output-Format

`ic search` gibt eine Trefferliste mit `Name — Org / Tel / Mail  ·UID-Kurzform`. Die Kurzform reicht für `ic show <prefix>`.

`ic show` gibt Markdown — Tim kann das direkt in Telegram lesen, mit allen Tel-Nummern, Mails, Adressen, Geburtstag, Notizen.

## Schreibzugriff (Don't, vorerst)

Dieser Skill ist **read-only**. iCloud-CardDAV unterstützt zwar PUT/DELETE für vCards, aber:
- Tim pflegt sein Adressbuch primär am iPhone — automatische Edits durch Jarvis sind risikoreich (Duplikate, kaputte Encoding-Kanten)
- Es gibt aktuell keinen erkennbaren Use Case dafür

Falls Tim mal sagt "trag XY in meine Kontakte ein" → vorher `request_approval` und manuell PUT bauen, oder Tim macht's selbst.

## iCloud-Eigenheiten

- Apple's vCards haben oft kein `FN` (Formatted Name) — der Skill rekonstruiert aus dem `N`-Feld (`FAMILY;GIVEN;...`) das `Given Family`-Format.
- `EMAIL`/`TEL`-Felder kommen oft als `item1.TEL`, `item2.EMAIL` — der Parser stripped den `itemN.`-Präfix.
- Photo-Felder werden ignoriert (Base64-PNGs aufblähen das Cache-File).
- vCards sind `vCard 3.0` mit Apple-Erweiterungen (`X-ABADR`, `X-IMAGEHASH`, `X-ADDRESSING-GRAMMAR`) — werden ebenfalls ignoriert.

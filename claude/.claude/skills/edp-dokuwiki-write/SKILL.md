---
name: edp-dokuwiki-write
description: >-
  This skill should be used when the user asks to edit, update, or create pages in the EDP DokuWiki
  (customer documentation). Trigger keywords: Wiki-Eintrag ändern, Wiki bearbeiten, Doku aktualisieren,
  "schreib einen neuen Wiki-Eintrag", "passe die Dokumentation an", "erstelle eine neue Wiki-Seite",
  DokuWiki bearbeiten, Wiki-Seite anlegen, Dokumentation ergänzen.
disable-model-invocation: true
allowed-tools: Bash(curl *), Read
argument-hint: [page-id]
---

# EDP DokuWiki bearbeiten

Bearbeitet bestehende oder erstellt neue Seiten im EDP DokuWiki.

## Voraussetzungen
- Env: `DOKUWIKI_URL`, `DOKUWIKI_USER`, `DOKUWIKI_PASSWORD`
- Tools: `curl`

Voraussetzungen gemäss `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Schritt 1: Zielseite bestimmen

Die Page-ID aus `$ARGUMENTS` oder dem Gesprächskontext ermitteln.

- Format: `namespace:seitenname` (z.B. `edpweb3:jwt_external`)
- Für neue Seiten: Passenden Namespace und Seitennamen mit dem User abstimmen

Verfügbare Namespaces:
`edpweb3`, `edpweb`, `elp`, `edpmap`, `editor`, `server`, `guardian`, `einsatzmonitor`, `einsatzserver`, `edptraining`, `edpmaplight`

## Schritt 2: Login

```bash
curl -s -c /tmp/dokuwiki_cookies.txt \
  -d "u=${DOKUWIKI_USER}&p=${DOKUWIKI_PASSWORD}&do=login&id=start" \
  "${DOKUWIKI_URL}/doku.php" -o /dev/null
```

## Schritt 3: Aktuellen Inhalt laden

Bestehenden Wiki-Text abrufen (liefert leeren Body bei neuen Seiten):

```bash
curl -s -b /tmp/dokuwiki_cookies.txt \
  "${DOKUWIKI_URL}/doku.php?id=PAGE_ID&do=export_raw"
```

## Schritt 4: Edit-Tokens holen

Die CSRF- und Konflikt-Tokens aus dem Edit-Formular extrahieren:

```bash
curl -s -b /tmp/dokuwiki_cookies.txt \
  "${DOKUWIKI_URL}/doku.php?id=PAGE_ID&do=edit" | \
  grep -o 'name="sectok" value="[^"]*"\|name="changecheck" value="[^"]*"\|name="date" value="[^"]*"'
```

Daraus extrahieren:
- `sectok` — CSRF-Token
- `changecheck` — Konflikterkennung-Hash
- `date` — Unix-Timestamp der letzten Änderung

## Schritt 5: Neuen Wiki-Text vorbereiten

Den neuen Wiki-Text zusammenstellen. Dabei die DokuWiki-Syntax verwenden:

```
====== Überschrift H1 ======
===== Überschrift H2 =====
==== Überschrift H3 ====
=== Überschrift H4 ===

Normaler Text. **Fett**, //kursiv//, __unterstrichen__, ''monospace''.

  * Listenpunkt (2 Leerzeichen + * + Leerzeichen)
  * Zweiter Punkt
    * Eingerückt (4 Leerzeichen)
  - Nummeriert (2 Leerzeichen + - + Leerzeichen)

<code>
Code-Block
</code>

<code ini>
[Abschnitt]
Key=Value
</code>

[[namespace:seite|Linktext]]          Interner Link
[[https://example.com|Externer Link]]  Externer Link

{{:namespace:bild.png|Beschreibung}}  Bild einbinden

^ Spalte 1 ^ Spalte 2 ^ Spalte 3 ^   Tabellenkopf
| Zelle 1  | Zelle 2  | Zelle 3  |   Tabellenzeile

<WRAP info>Infobox-Text</WRAP>        Bootstrap-Infobox
<WRAP alert>Warnung</WRAP>            Bootstrap-Warnung
```

**Wichtig:** Den kompletten Seiteninhalt als `wikitext` senden — nicht nur den geänderten Abschnitt.

Den neuen Wiki-Text in eine temporäre Datei schreiben:

```bash
cat > /tmp/dokuwiki_wikitext.txt << 'WIKIEOF'
...der komplette neue Wiki-Text...
WIKIEOF
```

## Schritt 6: Änderung dem User zur Bestätigung zeigen

Vor dem Speichern dem User den neuen Inhalt zeigen und um Bestätigung bitten. Dabei kurz zusammenfassen, was geändert wurde.

## Schritt 7: Speichern

Per POST an das Edit-Formular senden:

```bash
curl -s -b /tmp/dokuwiki_cookies.txt \
  -X POST "${DOKUWIKI_URL}/doku.php?id=PAGE_ID&do=edit" \
  --data-urlencode "sectok=SECTOK_VALUE" \
  --data-urlencode "id=PAGE_ID" \
  -d "rev=0" \
  --data-urlencode "date=DATE_VALUE" \
  --data-urlencode "changecheck=CHANGECHECK_VALUE" \
  -d "prefix=." \
  -d "suffix=" \
  -d "target=section" \
  --data-urlencode "wikitext@/tmp/dokuwiki_wikitext.txt" \
  --data-urlencode "summary=ZUSAMMENFASSUNG" \
  -d "do[save]=1" \
  -o /dev/null -w "%{http_code}"
```

Erwartete Antwort: HTTP `302` (Redirect zur gespeicherten Seite).

## Schritt 8: Speicherung verifizieren

Den gespeicherten Inhalt erneut abrufen und prüfen, ob die Änderungen übernommen wurden:

```bash
curl -s -b /tmp/dokuwiki_cookies.txt \
  "${DOKUWIKI_URL}/doku.php?id=PAGE_ID&do=export_raw" | head -5
```

Dem User das Ergebnis mit Link zur Seite mitteilen:
`${DOKUWIKI_URL}/doku.php?id=PAGE_ID`

## Schritt 9: Aufräumen

```bash
rm -f /tmp/dokuwiki_wikitext.txt
```

Abschliessend `skill-optimize` mit `edp-dokuwiki-write` aufrufen.

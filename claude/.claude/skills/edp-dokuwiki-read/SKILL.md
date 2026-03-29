---
name: edp-dokuwiki-read
description: >-
  This skill should be used when the user asks to read, look up, or research topics in the EDP DokuWiki
  (customer documentation). Trigger keywords: Dokuwiki, Wiki nachschauen, Wiki lesen, "schau mal im Wiki",
  "was steht im Wiki zu", Dokumentation nachschlagen, DokuWiki anschauen, "lies mal nach zu".
allowed-tools: Bash(curl *), Read
argument-hint: [Suchbegriff oder Thema]
---

# EDP DokuWiki lesen

Liest Seiten aus dem EDP DokuWiki (Kundendokumentation) zu einem bestimmten Thema.

## Voraussetzungen
- Env: `DOKUWIKI_URL`, `DOKUWIKI_USER`, `DOKUWIKI_PASSWORD`
- Tools: `curl`

Voraussetzungen gemäss `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Schritt 1: Thema bestimmen

Das Thema aus `$ARGUMENTS` extrahieren. Falls leer, den User fragen.

## Schritt 2: Login

```bash
curl -s -c /tmp/dokuwiki_cookies.txt \
  -d "u=${DOKUWIKI_USER}&p=${DOKUWIKI_PASSWORD}&do=login&id=start" \
  "${DOKUWIKI_URL}/doku.php" -o /dev/null
```

## Schritt 3: Suche

Nach dem Thema im Wiki suchen und die Suchergebnis-Seite parsen:

```bash
curl -s -b /tmp/dokuwiki_cookies.txt \
  "${DOKUWIKI_URL}/doku.php?do=search&id=start&q=SUCHBEGRIFF"
```

Aus dem HTML die Page-IDs der Treffer extrahieren (Pattern: `href="...?id=NAMESPACE:SEITE"`).

Die Namespaces im Wiki sind:
- `edpweb3` — edp:web 3 (Browser-Lösung)
- `edpweb` — edp:web 2
- `elp` — edp:desk (Desktop)
- `edpmap` — edp:map (GIS/Karte)
- `editor` — Editor (Datenpflege)
- `server` — EDP-Server
- `guardian` — EDP Guardian
- `einsatzmonitor` — Einsatzanzeigemonitor
- `einsatzserver` — Einsatzserver
- `edptraining` — edp:training
- `edpmaplight` — edp:map light

## Schritt 4: Seiten lesen

Für jeden relevanten Treffer den Roh-Text abrufen:

```bash
curl -s -b /tmp/dokuwiki_cookies.txt \
  "${DOKUWIKI_URL}/doku.php?id=PAGE_ID&do=export_raw"
```

Falls die Suche zu viele Treffer liefert: Die 3-5 relevantesten Seiten auswählen.

## Schritt 5: Ergebnis aufbereiten

Den Wiki-Inhalt dem User zusammengefasst präsentieren:
- Seitenname und URL angeben (Format: `${DOKUWIKI_URL}/doku.php?id=PAGE_ID`)
- Relevante Abschnitte hervorheben
- Bei mehreren Seiten eine kurze Übersicht geben, welche Seite was abdeckt

### DokuWiki-Syntax Referenz (zum Lesen)
- `====== H1 ======`, `===== H2 =====`, `==== H3 ====`
- `**fett**`, `//kursiv//`, `__unterstrichen__`
- `<code>...</code>` = Code-Block
- `  * ` = Listenpunkt (2 Leerzeichen Einrückung)
- `[[namespace:seite|Text]]` = interner Link

Abschliessend `skill-optimize` mit `edp-dokuwiki-read` aufrufen.

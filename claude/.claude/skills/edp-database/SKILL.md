---
name: edp-database
description: "This skill should be used when the user asks to query the EDP database, check table structures, verify column values, look up EDP data, or when any task requires current information from the EDP MariaDB database on the dev VM. Trigger keywords: Datenbank, database, DB, Tabelle, SQL, query, abfragen, nachschauen, verifizieren, Spalte, column."
argument-hint: [SQL-Query oder Tabellenname]
allowed-tools: Bash, Read
---

# EDP-Datenbank abfragen

Führt SQL-Queries gegen die EDP MariaDB auf der Developer-VM aus.

## Voraussetzungen
- Tools: `ssh`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Verbindungsdaten

- **SSH-Host**: `vm-eifert-develop` (muss in `~/.ssh/config` konfiguriert sein)
- **MariaDB-Binary**: `C:\Program Files\MariaDB 10.11\bin\mysql.exe`
- **User**: `root`
- **Passwort**: `EDP`
- **Datenbank**: `EDPdb`

## Schritt 1: Query bestimmen

Aus `$ARGUMENTS` die auszuführende SQL-Query ableiten:

- Wenn eine fertige SQL-Query übergeben wurde: direkt verwenden
- Wenn ein Tabellenname übergeben wurde: `DESCRIBE {tabelle};` ausführen
- Wenn eine inhaltliche Frage gestellt wurde: passende SQL-Query formulieren
- Wenn nichts übergeben wurde: `SHOW TABLES;` ausführen

## Schritt 2: Query ausführen

Query per SSH auf der Dev-VM ausführen:

```bash
ssh vm-eifert-develop "\"C:\\Program Files\\MariaDB 10.11\\bin\\mysql.exe\" -u root -pEDP EDPdb -e \"{query}\""
```

**Hinweise:**
- Escaping beachten: Doppelte Anführungszeichen innerhalb der Query müssen escaped werden
- Bei großen Ergebnismengen `LIMIT` verwenden
- Bei `DESCRIBE` oder `SHOW` kein Limit nötig
- Wenn Host-Key noch unbekannt: `-o StrictHostKeyChecking=accept-new` beim ersten Mal nutzen

## Schritt 3: Ergebnis aufbereiten

Ergebnis übersichtlich darstellen. Bei Tabellenstrukturen die relevanten Spalten hervorheben. Bei Datenabfragen die Ergebnisse kontextualisieren.

Abschließend `skill-optimize` mit `edp-database` aufrufen.

---
name: store-credential
description: Stores credentials, API tokens, and environment variables persistently in /etc/environment. Use when asked to "save a token", "store credentials", "persist an env var", "add an API key", or when a new credential needs to be stored permanently.
disable-model-invocation: true
argument-hint: [VAR_NAME=value]
allowed-tools: Bash, Read
---

# Credential speichern

Speichert Zugangsdaten (API-Tokens, Passwörter, Env-Vars) persistent in `/etc/environment`. Diese Datei ist als Hostpath gemountet und überlebt Container-Neustarts.

## Schritt 1: Argumente parsen

Aus `$ARGUMENTS` extrahieren:
- **Variable**: `KEY=VALUE` Format

Falls `$ARGUMENTS` leer oder kein `=` enthalten:
- Nach Variablenname und Wert fragen
- Kommunikationsweg gemäß `CLAUDE_COMM_CHANNEL` wählen (siehe `.shared/communication.md`)

Falls nur ein Key ohne Value angegeben wurde (z.B. `MY_TOKEN`): nach dem Wert fragen.

## Schritt 2: Validierung

1. **Key prüfen**: Nur Großbuchstaben, Zahlen und Unterstriche erlaubt (`^[A-Z][A-Z0-9_]*$`)
2. **Value prüfen**: Darf nicht leer sein
3. **Kollision prüfen**: `/etc/environment` lesen und prüfen ob der Key bereits existiert

Falls der Key existiert:
- Den aktuellen Wert anzeigen (gekürzt, nur erste/letzte 4 Zeichen bei langen Werten)
- Fragen ob überschrieben werden soll
- Kommunikationsweg gemäß `CLAUDE_COMM_CHANNEL` wählen (siehe `.shared/communication.md`)

## Schritt 3: In /etc/environment schreiben

Falls der Key bereits existiert, die bestehende Zeile ersetzen. Sonst am Ende anhängen.

Value in Double-Quotes setzen wenn er Sonderzeichen enthält (Leerzeichen, `$`, `&`, etc.).

```bash
# Neue Variable anhängen
echo 'KEY=VALUE' >> /etc/environment

# Bestehende Variable ersetzen
sed -i 's/^KEY=.*/KEY=VALUE/' /etc/environment
```

## Schritt 4: In aktuelle Session laden

Die Variable sofort in der aktuellen Shell-Session verfügbar machen:

```bash
export KEY=VALUE
```

## Schritt 5: Bestätigung

Dem User bestätigen:
- Variablenname
- Wert (gekürzt anzeigen — erste 4 und letzte 4 Zeichen, Rest als `***`)
- Hinweis dass die Variable sofort und nach Neustarts verfügbar ist

Abschließend `skill-optimize` mit `store-credential` aufrufen.

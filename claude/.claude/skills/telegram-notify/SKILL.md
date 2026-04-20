---
name: telegram-notify
description: Sendet eine Telegram-Benachrichtigung an den User. Wird automatisch aufgerufen wenn der User Phrasen verwendet wie "sag mir dann Bescheid", "benachrichtige mich", "schick mir Bescheid", "sende mir eine Nachricht wenn fertig", "und gib mir Bescheid", "notify me", "let me know when done". Schickt eine kontextuelle Zusammenfassung der abgeschlossenen Aufgabe via Telegram Bot API.
allowed-tools: Bash
---

# Telegram-Benachrichtigung senden

Sendet eine kontextuelle Benachrichtigung an den User via Telegram, sobald eine Aufgabe abgeschlossen ist.

## Voraussetzungen

- Env: `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag Einrichtungshinweis ausgeben und abbrechen.

### Einrichtung (falls Voraussetzungen fehlen)

Die Variablen in `~/.claude/settings.json` unter `env` setzen:

```json
{
  "env": {
    "TELEGRAM_BOT_TOKEN": "1234567890:ABCdefGHI...",
    "TELEGRAM_CHAT_ID": "987654321"
  }
}
```

Oder per `/update-config` Skill eintragen lassen.

**Bot-Token erhalten**: BotFather auf Telegram anschreiben → `/newbot` → Token kopieren.
**Chat-ID ermitteln**: `https://api.telegram.org/bot<TOKEN>/getUpdates` aufrufen, nachdem eine Nachricht an den Bot gesendet wurde.

## Schritt 1: Nachricht formulieren

Formuliere eine kurze, prägnante Nachricht (2–4 Sätze) auf Deutsch:
- Was wurde erledigt
- Ggf. wichtigste Ergebnisse oder nächste Schritte
- Halte sie knapp — Telegram-Benachrichtigungen sollen auf einen Blick lesbar sein

Format:
```
✅ *Aufgabe abgeschlossen*

<Zusammenfassung was erledigt wurde>
```

## Schritt 2: Nachricht senden

Sende die Nachricht via Telegram Bot API:

```bash
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=<formulierte Nachricht>" \
  --data-urlencode "parse_mode=Markdown"
```

Prüfe den HTTP-Response: `"ok":true` = Erfolg. Bei Fehler die Fehlermeldung aus `"description"` ausgeben.

Abschließend `skill-optimize` mit `telegram-notify` aufrufen.

---
name: regeln-versand
description: Tims Regel vor jedem externen Versand: den Empfänger aus einem frischen, vorgangseigenen Abruf verifizieren und geteilten Temp-Dateien nicht trauen. Nutzen vor jeder Zammad-Mail, jedem SMTP-Versand und jedem Schreibzugriff auf fremde Systeme.
---

# Versand — Tims Regeln

Diese Regeln galten bis 2026-08-26 als "universell" und lagen in `CLAUDE.md`.
Sie greifen aber nur in diesem Zusammenhang — deshalb stehen sie hier und
kosten nichts, solange der Zusammenhang nicht vorliegt.

## externer-versand-empfaenger-verifizieren

vor jedem externen Versand (Zammad-Mail, SMTP, fremde Repos) den Empfänger/das Ziel aus einem **frischen, ticket-eigenen** Fetch verifizieren (gegen `.customer` UND letzten Customer-Artikel-`from`); geteilten/wiederverwendeten Temp-Dateien der Skills (`/tmp/z_*.json`) NICHT trauen — die werden cross-ticket überschrieben (Beinahe-Fehlversand an fremde Org, EDP#7619889). Ziel-Verify *vor* Versand, ergänzt  (Read-back *nach* Mutation). Volltext:

---

Was hier steht, ist die **geltende Fassung**.

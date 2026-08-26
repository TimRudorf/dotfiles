---
name: regeln-debugging
description: Tims Regeln für Fehlersuche: den gemeldeten Pfad exakt nachstellen statt den benachbarten, Lock- und Thread-Änderungen unter dem echten parallelen Szenario verifizieren, einen roten Test erst gegen die unveränderte Baseline isolieren. Nutzen bei Fehlerreproduktion, Race-Conditions und flaky Tests.
---

# Debugging — Tims Regeln

Diese Regeln galten bis 2026-08-26 als "universell" und lagen in `CLAUDE.md`.
Sie greifen aber nur in diesem Zusammenhang — deshalb stehen sie hier und
kosten nichts, solange der Zusammenhang nicht vorliegt.

## fehler-reproduktion-exakter-pfad

bei Fehler-Reproduktion exakt den vom Melder gemeldeten Trigger/Pfad nachstellen (nicht den benachbarten); Code-Pfad vom Trigger bis Fehlerpunkt verfolgen, jeden gemeldeten Pfad einzeln testen, Beweismaterial (Logs) gegen den getesteten Pfad gegenchecken. Sonst falsches „liegt-nicht-bei-uns"-Verdikt. Volltext: `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/fehler-reproduktion-exakter-pfad.md` (Archiv)

## concurrency-fix-baseline-verify

Lock-/Thread-/Recovery-Änderung unter dem **echten parallelen Szenario** live-verifizieren (grüne Units reichen nicht; ein Lock serialisiert evtl. mehr als seinen sichtbaren Zweck — eine Op aus dem Lock zu ziehen kann eine versteckte Serialisierung entfernen → Race). Roten/flaky Test nach einer Änderung erst gegen die **unveränderte Baseline** isolieren (introduced vs pre-existing, genug Wiederholungen für Aussagekraft), bevor man ihn als „flaky/pre-existing" wegerklärt. Volltext: `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/concurrency-fix-baseline-verify.md` (Archiv)

---

Was hier steht, ist die **geltende Fassung**. Die ausführlichen Begründungen
von früher liegen im Archiv unter `~/VAULT_BACKUP/jarvis-wiki-2026-08-26/tim/feedback/` — dort nachlesen,
wenn ein Grenzfall unklar bleibt, aber im Zweifel gilt dieser Text.

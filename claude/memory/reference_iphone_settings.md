---
name: Tims iPhone-Settings (relevant für Datenfluss)
description: iOS-Settings die Tims Daten-Pipelines beeinflussen — Background App Refresh, Apple Watch, etc.
type: reference
originSessionId: 6da8ffce-ed73-4d31-92fe-c648997a3234
---
**Background App Refresh: überall AUS** (Stand 2026-04-27)

Tim hat Background App Refresh systemweit deaktiviert — ist eine bewusste Entscheidung (Akku-Optimierung / Privacy). Konsequenz für Apps die im Hintergrund Daten pushen sollen:

- **Health Auto Export** kann nicht "stündlich" oder "täglich" zuverlässig im Hintergrund triggern, auch wenn die Sync Cadence so eingestellt ist
- AHE syncht **nur wenn Tim die App selbst öffnet** (oder iOS sie aus anderen Gründen weckt)
- **Pareto-Workaround:** Tim öffnet AHE manuell (z.B. morgens nach dem Wiegen). Reicht für täglichen Sync.

**How to apply:**
- Bei iOS-Apps die Hintergrund-Tasks brauchen würden: nicht annehmen dass sie automatisch laufen.
- Bei Daten-Pipeline-Debugging "warum sind Daten alt": Frage als erstes "hast du AHE in den letzten X Stunden mal aufgemacht?"
- Bei neuen Setup-Vorschlägen: keinen Workflow bauen der von Background App Refresh abhängt; manuelle Trigger oder serverseitige Polls bevorzugen.
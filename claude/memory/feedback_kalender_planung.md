---
name: Kalender-Planung — Routinen intern, Einzeltermine einen Schritt voraus
description: Tim will keine RRULE-Serien, sondern täglich/wöchentlich neu generierte Einzeltermine — damit Konflikte beim Eintragen sichtbar sind
type: feedback
originSessionId: d0423f1a-b3e2-4f7c-af1e-6e691e76d6d4
---
Tim's Modell für Tages-/Wochenplanung in Nextcloud:

- **Routinen-Template ist INTERN** bei mir (z.B. JSON unter `/workspace/`) — nicht als RRULE im Kalender
- **Konkrete Einzeltermine** werden ~1 Woche im Voraus eingetragen
- Beim Eintragen schaue ich Tims existierende Kalendereinträge an → erkenne aktiv Konflikte (Hochzeiten, RD-Dienste, Termine, Reisen) → löse sie auf, statt sie stillschweigend zu überlagern
- Tagesplan kann täglich noch nachjustiert werden, wenn was reinkommt

**Why:** Tim sagte am 2026-04-27 explizit: "Wenn du fix in den Kalender einträgst, siehst du nicht, wenn in der Zukunft Konflikte da sind, weil da zum Beispiel eine Hochzeit ist." RRULE-Serien sind blind für Sondertermine. Einzeltermin-Eintragung erzwingt Konflikt-Awareness.

**How to apply:**
- Vor jedem Eintragen: existierende Events im Zeitraum lesen, NICHT blind überlappen
- Konflikt-Auflösung: verschieben, kürzen, weglassen — je nach Lage und Wichtigkeit
- Routinen-Config wird gepflegt unter `/workspace/jarvis-tagesplan/routines.json` (oder vergleichbarem Pfad — host-übergreifend gilt: das Template lebt in der Workspace-Struktur, nicht im Kalender selbst)
- Plan-Vorlauf: standardmäßig 7 Tage; bei naher Klausurphase ggf. mehr
- Re-Plan-Frequenz: wöchentlich (So Abend) als Hauptplanung + tägliche Morgen-Adjustments
- Gilt für alle Tagesplan-Routinen: Aufstehen, Bett, Mittag, Magerquark, Lernblöcke, EDP-Slots
- Pflicht-Termine (Klausur, PPM, Jourfix, Team-Summit, Sport-Termine) sind separat und können einmalig direkt eingetragen werden — die sind ja keine "Routine", sondern feste Einzelereignisse

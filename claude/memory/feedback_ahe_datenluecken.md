---
name: AHE-Daten haben Lücken — nicht als TDEE-Quelle nutzen
description: Apple-Watch-Daten in der Pipeline sind unregelmäßig synchronisiert; Active Energy taugt nicht für Kalorien-Bilanzierung
type: feedback
originSessionId: af83e9d2-b5c7-4764-a46f-a562bae1d782
---
**Regel:** Active-Energy- und Step-Count-Werte aus der Apple-Health-Pipeline **nicht** als verlässliche TDEE-/Kalorienverbrauchsquelle nutzen. Workout-Records ebenfalls **lückenhaft** — nicht jedes Training landet als getracktes Workout in der Watch (z.B. Krafttraining oft nicht).

**Why:** Beobachtet 2026-04-27 beim ersten Auswerten von Tims Daten: viele Tage haben 0 Active-Energy oder unter 100 kcal, obwohl er nachweislich trainiert. AHE läuft nur bei entsperrtem iPhone (siehe project_apple_health_pipeline.md), Tim trägt die Watch nicht durchgängig, und Krafttraining wird nicht immer als Workout gestartet. Daraus berechnete TDEE-Schätzungen wären massiv unterschätzt.

**How to apply:**
- Für Kalorien-Modelle: Mifflin-St-Jeor + Aktivitätsfaktor aus Tim-Selbstauskunft, **nicht** AHE-Daten.
- Trends in Schritten/Active-Energy nur als grobe "gab es überhaupt Bewegung"-Indikator interpretieren — nie absolute Werte vergleichen.
- VO2max-Trend, Resting-HR-Trend (über lange Zeit) sind hingegen einigermaßen belastbar, weil Apple die Werte ohnehin nur mit gewisser Konfidenz schätzt.
- Gewicht (Renpho → Health → AHE) **bleibt** der harte Datenpunkt.

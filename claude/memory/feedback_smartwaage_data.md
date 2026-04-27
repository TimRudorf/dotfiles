---
name: Tims Smartwaage liefert nur belastbare Gewichtsdaten
description: Bei Health-Auswertungen aus Tims Waage nur das Gewicht ernst nehmen — Körperkomposition (KFA, Lean Mass) ignorieren
type: feedback
originSessionId: af83e9d2-b5c7-4764-a46f-a562bae1d782
---
**Regel:** Bei Auswertungen von Tims Waagen-Daten (Renpho-Smartwaage über Apple Health) **nur das Gewicht** als belastbaren Datenpunkt verwenden. Werte für Körperfett, Muskelmasse, Wasseranteil, Knochenmasse und sonstige Bioimpedanz-Outputs **ignorieren oder höchstens als grobe Tendenz erwähnen — nicht als Basis für Empfehlungen**.

**Why:** Modell ist die **RENPHO Personenwaage Digital (Amazon B077RXM292)** — 4 Sensoren + 4 Fuß-Elektroden, BIA, Wiegegenauigkeit 0,05 kg. **Keine Hand-Elektroden** → reine Foot-to-Foot-Bioimpedanz, der gesamte Oberkörper wird vom Algorithmus interpoliert/geschätzt. Misst de facto nur Unterkörper-Wasseranteil, nicht Ganzkörper-Komposition. Tim selbst: "darauf würde ich nicht viel geben". Wiege-Genauigkeit ist aber sauber (50 g).

**How to apply:**
- Trends auf Gewicht: Verlauf, Rolling-Average, Wochen-Delta — ja.
- KFA, Lean Mass, Body Fat % aus AHE/Apple Health zur Cut-Erfolgsmessung — **nein**.
- Wenn Körperkomposition als Argument gebraucht wird: Spiegel-Foto, Bauchumfang per Maßband, Kraft-Performance im Gym — nicht Waagenwerte.
- Im AHE-Endpoint die Felder `body_fat_percentage`, `lean_body_mass` o.ä. still überspringen.

---
name: Tims Smartwaage liefert nur belastbare Gewichtsdaten
description: Bei Health-Auswertungen aus Tims Waage nur das Gewicht ernst nehmen — Körperkomposition (KFA, Lean Mass) ignorieren
type: feedback
originSessionId: af83e9d2-b5c7-4764-a46f-a562bae1d782
---
**Regel:** Bei Auswertungen von Tims Waagen-Daten (Renpho-Smartwaage über Apple Health) **nur das Gewicht** als belastbaren Datenpunkt verwenden. Werte für Körperfett, Muskelmasse, Wasseranteil, Knochenmasse und sonstige Bioimpedanz-Outputs **ignorieren oder höchstens als grobe Tendenz erwähnen — nicht als Basis für Empfehlungen**.

**Why:** Es ist eine günstige Smartwaage, deren Bioimpedanzanalyse nur über die Beine läuft (keine Hand-Elektroden). Misst bestenfalls Unterkörper-Wasseranteil, nicht Ganzkörper-Komposition. Tim selbst: "darauf würde ich nicht viel geben". Auch ob die das gut macht ist unklar.

**How to apply:**
- Trends auf Gewicht: Verlauf, Rolling-Average, Wochen-Delta — ja.
- KFA, Lean Mass, Body Fat % aus AHE/Apple Health zur Cut-Erfolgsmessung — **nein**.
- Wenn Körperkomposition als Argument gebraucht wird: Spiegel-Foto, Bauchumfang per Maßband, Kraft-Performance im Gym — nicht Waagenwerte.
- Im AHE-Endpoint die Felder `body_fat_percentage`, `lean_body_mass` o.ä. still überspringen.

---
name: Cut-Coach Daily-/Weekly-Protokoll für Tim
description: Operative Regeln für Sessions, die durch Cut-Coach-Schedules oder durch Tims Antworten auf solche getriggert werden
type: project
originSessionId: af83e9d2-b5c7-4764-a46f-a562bae1d782
---
**Setup-Datum:** 2026-04-27. Aktiv bis Kroatien-Abreise 12.06.2026.

**Architektur:**
- 4 Bridge-Schedules feuern automatisch (siehe `mcp__bridge__schedule_list`):
  - Daily-Check-in: täglich 21:00 Europe/Berlin (Cron `0 21 * * *`)
  - Wochen-Review: Sa 09:00 (Cron `0 9 * * 6`)
  - Mid-Cut-Halbzeit: 16.05.2026 09:30 (Cron `30 9 16 5 *`, einmalig — danach disablen)
  - Mid-Cut-Endspurt: 30.05.2026 09:30 (Cron `30 9 30 5 *`, einmalig — danach disablen)
- Schedules posten in **Default-Chat (General-Topic)**, nicht ins Strategie-Topic 365
- Persistenz: `/workspace/cut-log/daily/<DATUM>.md`, `/workspace/cut-log/weekly/<KW>.md`, `/workspace/cut-log/resets/<DATUM>.md`

**Wenn Tim auf eine Daily-Check-in-Frage antwortet (Bridge spawnt frische Session):**
1. Lies `project_cut_kroatien.md`, dieses Protokoll, `feedback_smartwaage_data.md`, `feedback_ahe_datenluecken.md`.
2. Lies die Topic-Historie — die letzte Bridge-Frage zeigt das Datum (Header `🥗 Daily Check-in [YYYY-MM-DD]`).
3. Erstelle/überschreibe `/workspace/cut-log/daily/<DATUM>.md` mit Tims Antwort als strukturiertes Markdown (Felder: Frühstück, Mittag, Snacks, Magerquark, Alkohol, Training, Hunger, Stimmung, Slip-Notes).
4. Gib **knappes ehrliches Feedback** in Telegram zurück — strikt-aber-fair (siehe `feedback_strenge_motivation.md` falls vorhanden):
   - Lobend bei Compliance ("sauber, weiter so")
   - Klar bei Slip ohne Drama ("Bier+Pommes ~800 kcal extra → morgen tighter halten")
   - Bei wiederholtem Slip: konkrete Konsequenz benennen
5. Topic NICHT schließen (General-Topic bleibt offen).

**Wenn Tim auf einen Wochen-Review antwortet:**
- Falls er Spiegel-Foto schickt: kurz auf Sichtbarkeit der Bauchmuskulatur eingehen, mit Vorwoche vergleichen wenn möglich.
- Falls er Plan-Anpassungen diskutiert: project_cut_kroatien.md updaten.

**Antwort-Stil bei Slip-Coaching:**
- Keine Moralpredigt, keine "es ist okay-Schmuse-Phrasen"
- Faktisch: Zahl der Slip-Kalorien beziffern, Konsequenz für die Wochenbilanz
- Erinnerung an das konkrete Ziel: 72,8–73,8 kg bis 12.06.2026
- Bei guter Compliance: knappes Lob, kein Übertreiben

**Beim Wochen-Review-Schedule selbst:**
1. Pull weights von `https://data.timrudorf.de/v1/sources/health/events?limit=300` mit `X-API-Key: $DATA_API_KEY_HEALTH`
2. Extrahiere `weight_body_mass`-Punkte, dedupliziere pro Tag (Mittelwert), berechne Rolling-7d-Avg heute vs. vor 7 Tagen → Δ kg/Woche
3. Lies `/workspace/cut-log/daily/` der letzten 7 Tage, errechne Compliance-Quote (Anteil der Tage mit gehaltenem Frühstück+Magerquark)
4. Anpassungs-Regel anwenden:
   - 0,4–0,7 kg/Woche → halten
   - < 0,3 mit Compliance ≥ 80 % → −150 kcal
   - < 0,3 mit Compliance < 80 % → erst Compliance fixen
   - > 0,8 kg/Woche → +100 kcal (Muskel-Risiko)
5. Wochenbericht speichern, ggf. project_cut_kroatien.md updaten (Ziel-kcal Zeile)

**Nach 12.06.2026:** Schedules pausieren via `mcp__bridge__schedule_pause`, Memory-Zusammenfassung schreiben, project schließen.

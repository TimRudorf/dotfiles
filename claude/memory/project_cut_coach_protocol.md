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
3. **Wenn Mittag-Foto mitgeschickt wurde:** Bild mit Read öffnen, Komponenten erkennen (Hauptprotein, Carbs, Fett-Quellen, Beilagen), kcal+Protein abschätzen — Range angeben (z.B. "~700–850 kcal, ~35–45 g P"), nicht Pseudo-Präzision. Schätzung im `lunch.kcal_estimate`/`protein_g_estimate` ablegen, `photo_provided: true`. Wenn unsicher: konservativ nach OBEN runden (Cut → besser leicht überschätzt als unterschätzt).
4. **Parse Tims Antwort in strukturiertes Markdown mit YAML-Frontmatter** und speichere unter `/workspace/cut-log/daily/<DATUM>.md`. Schema (siehe unten).
5. Gib **knappes ehrliches Feedback** in Telegram zurück — strikt-aber-fair:
   - Lobend bei Compliance ("sauber, weiter so")
   - Klar bei Slip ohne Drama ("Bier+Pommes ~800 kcal extra → morgen tighter halten")
   - Bei wiederholtem Slip: konkrete Konsequenz benennen
   - Bei Schlaf < 6h für 3+ Tage in Folge: kurzer Hinweis auf Cut-Auswirkung (Cortisol/Hunger/Recovery)
   - Bei Trainings-Progressions-Stillstand >2 Wochen im Cut: erwartbar, nicht besorgt sein, Tim beruhigen
6. Topic NICHT schließen (General-Topic bleibt offen).

**Daily-Check-in Frage-Format (was die Bridge um 21:00 fragt — bewusst kompakt, alle Felder optional):**

> 🥗 **Daily Check-in [YYYY-MM-DD]**
> Frühstück: Plan / anders / ausgelassen?
> Mittag: was, wo? — Foto gerne, ich rechne dann.
> Snacks?
> Magerquark abends: ✅ / ❌
> Alkohol?
> Training: was, wie's lief — falls Buch dabei, Top-Lift kurz reinwerfen
> Schlaf: Stunden + 1-5
> Hunger / Stimmung 1-5

**Daily-Log Schema (`/workspace/cut-log/daily/YYYY-MM-DD.md`):**
```markdown
---
date: 2026-04-27
day_n: 1
breakfast:
  status: hit | partial | miss   # hit=Plan-Skyr-Bowl, partial=modifiziert, miss=ausgelassen/anders
  detail: "Kurzbeschreibung"
  kcal_estimate: 480
lunch:
  detail: "Was gegessen, wo"
  kcal_estimate: 750
  protein_g_estimate: 35
  status: on_plan | over | low_protein | carb_heavy | junk
  photo_provided: true|false    # Foto vom Mittag erhalten? (Standard-Tracking-Modus für Mittag)
snacks:
  detail: ""
  kcal_estimate: 0
magerquark_evening:
  status: hit | miss
  detail: ""
alcohol:
  had: false
  kind: ""           # "Bier", "Wein", etc.
  units: 0           # Bier=0,5l=1 unit; Glas Wein=1; Shot=0,5
  kcal_estimate: 0
training:
  done: true|false
  type: "Krafttraining Push" | "Run" | "Rest" etc.
  duration_min: 60
  perceived: "stark" | "ok" | "schwach"
  progression_notes: ""    # was er aus dem Trainings-Buch zitiert: Übung+Gewicht+Reps,
                           # Vergleich zur Vorwoche wenn er was sagt (Steigerung/Halten/Fall)
sleep:
  hours: 7.5               # Stunden, wie Tim sie nennt
  quality_1_5: 4           # subjektiv 1=mies / 5=top
  notes: ""                # nur wenn besonders
hunger_1_5: 3
mood_1_5: 4
slip_notes: "Restaurant mit Tilman, Pommes statt Bowl"
total_kcal_estimate: 2380
total_protein_g_estimate: 165
compliance_score: 92          # 0–100, Formel siehe unten
on_plan_overall: true
---

> Tims Antwort (Zitat):
> <Originaltext>

**Jarvis-Feedback:** <2-4 Sätze ehrlich>
```

**Compliance-Score-Formel (0–100):**
- Breakfast: hit=20, partial=10, miss=0
- Magerquark abends: hit=25, miss=0
- Total kcal in [2200, 2600]: +25 (over=0, unter 2000 = -5 Crash-Strafe)
- Protein ≥ 150 g: +15 (130–149: +8; <130: 0)
- Lunch nicht "junk": +10
- Mood/Hunger sustainability: 1–5 → keine direkten Punkte, aber Trend-Indikator
- Alkohol-Penalty: Score cap auf 95 wenn `alcohol.had=true` (Realität, nicht Moral)
- Max = 100 (clean) / 95 (mit Alkohol)

**Wochen-Aggregation (für Sa-Wiege-Review):**
- `avg_compliance` = Mittelwert der 7 daily compliance_scores
- `on_plan_days` = Anzahl Tage mit `on_plan_overall=true`
- `magerquark_hit_rate` = Anteil hit
- `alcohol_days` = Tage mit Alkohol
- `avg_kcal`, `avg_protein` = Mittelwerte
- `training_days` = Tage mit `training.done=true`
- Slip-Patterns: an welchen Wochentagen häufen sich Misses? (z.B. immer Fr/Sa → Wochenend-Problem)

**Diskriminator-Logik (im Sa-Wiege-Review explizit so anwenden):**

```
weekly_avg_compliance ≥ 85?
  ja → Tim hält den Plan sauber
       weight_delta < 0,3 kg/Woche  → "PLAN-PROBLEM" → −150 kcal
       weight_delta 0,4–0,7 kg/Woche → "PERFEKT" → halten
       weight_delta > 0,8 kg/Woche  → "ZU SCHNELL" → +100 kcal
  nein, 70–84 → "GEMISCHT" → erst Compliance auf 85+ ziehen, kein Plan-Tightening
       konkret nennen wo's hakt (Mittag? Wochenende? Alkohol?)
  nein, < 70 → "TIM-PROBLEM" → Plan-Anpassung GESPERRT bis Compliance fixed
       Strenge: Slip-Pattern beim Namen nennen, Konsequenz für Kroatien-Ziel ehrlich beziffern
```

Diese Logik ist die Antwort auf Tims explizite Frage "ist der Plan oder ich das Problem?" — Compliance-Score < 85 macht jede Plan-Anpassung sinnlos, weil wir nicht messen was wir denken zu messen.

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

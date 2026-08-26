---
name: tasks
description: Tims ToDo-System auf Todoist Pro. Use this skill when Tim wants to view, add, complete, or check tasks across his Areas (Inbox, Work, Uni, Privat) und Sub-Projects. Trigger keywords: "task", "todo", "aufgabe", "erledigt", "was muss ich noch", "trag ein", "merk dir", "neue aufgabe", "hak ab", "einkaufen", "rewe", "dm", "/tasks". Todoist iOS-/Mac-App ist Tims primäre UI; dieser Skill ist Jarvis' CRUD-Zugang via REST + Sync API.
---

# tasks — Todoist Bridge

Tims persönliches ToDo-System läuft seit 2026-05-05 in **Todoist Pro**. Native iOS-/Mac-App, dokumentierte API mit Sub-Sekunden-Sync. `jt`-CLI ist Jarvis' CRUD-Zugang.

## Project-Hierarchie (Areas + Sub-Projects)

```
Inbox
Work
 ├─ EDP
 ├─ Rettung
 └─ Wartet auf
Uni
 ├─ Lerneinheiten          (early-stage, deprecated)
 ├─ Klausurphase SS26
 ├─ 🔬 Thermo
 ├─ 📐 CPS
 ├─ 🤖 ML/DL
 ├─ 🏛 MF
 ├─ 💼 ES
 ├─ 📈 DIM
 ├─ 📝 PPM
 ├─ ⚙️ P-RT2
 ├─ 🔁 SD-RT3
 ├─ 📡 ST
 └─ 🎛 MPC
Privat
 ├─ Haushalt
 ├─ Cut & Training
 ├─ Einkauf REWE
 └─ Einkauf DM
```

Wenn ein Task in keine passt → Inbox. Areas (`Work`/`Uni`/`Privat`) sind Container — `jt add` erfordert ein Sub-Project, nicht die Area selbst.

## CLI

`/workspace/jarvis-tasks/jt`:

```
jt list [--list NAME] [--include-done] [--json]
jt pending [--json]                    alle offenen
jt since <iso-datetime> [--json]       was wurde seit X erledigt (für Status-Loop)
jt add <list> <title> [--due STR] [--prio low|med|high] [--note TEXT] [--label L1,L2]
jt done <task_id>                      (selten — Tim hakt selber in Todoist ab)
jt delete <task_id>
jt lists                               alle Project-Pfade ausgeben
```

`<list>` akzeptiert:
- `Inbox` — exakt
- `Work` (=`Arbeit`), `Uni`, `Privat` — Areas, expand auf Sub-Projects (für `list`/`pending`); für `add` zwingend Sub-Project angeben
- Voller Pfad: `Uni / 🔬 Thermo`, `Privat / Einkauf REWE`, `Work / EDP` — eindeutig

`--due` ist Natural-Language: `morgen 9h`, `2026-05-10`, `every monday`, `next friday`. Todoist parsed das selbst.
`--prio`: `low|med|high` → Todoist 1/3/4 (Todoist nennt p1 „high", interner Wert ist 4).
`--label`: Komma-Liste, automatisch wird `from-jarvis` ergänzt.

Vor jedem Aufruf: `set -a; source /opt/stacks/jarvis/.env; set +a` — `$TODOIST_API_TOKEN` muss gesetzt sein.

## Wann nutzen

- **Tim sagt** "trag ein …", "merk dir …", "neue aufgabe", "task <domain>: …" → `jt add`
- **Tim fragt** "was steht heute an", "was muss ich noch", "/tasks" → `jt pending`
- **Tagesabschluss** "was hab ich heute geschafft" → `jt since <heute-00:00Z>`
- **Listen-Zuordnung**: aus Tims Wording erkennen (`uni`/`klausur`/`thermo`/`cps`… → entsprechendes Modul-Sub-Project; `edp`/`kunde`/`ticket`/`zammad` → `Work / EDP`; `rettung`/`schicht` → `Work / Rettung`; Frisches/Gekühltes → `Privat / Einkauf REWE`; sonst Einkaufbares → `Privat / Einkauf DM` (Default); `putzen`/`reparieren` → `Privat / Haushalt`; sonst `Privat`; im Zweifel `Inbox`). Volle Einkauf-Heuristik in `tim/einkauf.md`.

## Eingabe-Heuristik

Tim spricht meistens unstrukturiert. Parse selbst:

- **Liste/Sub-Project** aus Kontext. Bei mehrdeutig: `Inbox`.
- **Due** aus relativen Wörtern oder konkreten Daten — gib es als `--due "morgen"` direkt weiter, Todoist parsed.
- **Prio** nur wenn Tim sie nennt ("dringend" → high, "irgendwann" → low). Default: keine.
- **Title** kurz halten — Todoist-Mobile zeigt ~80 Zeichen lesbar.
- **Note** (`--note`) optional für Kontext, Wikilinks ins Vault: `[[projekte/lernplan/cps/einheiten#L1]]`.

## Status-Loop

Todoist ist die **primäre Eingabe für Tim**. Wenn Tim einen Task abhakt, syncht Todoist das in <5 Sekunden auf alle Geräte; Jarvis sieht es per Polling über `jt since` oder direktem REST-Call. Webhooks sind aktuell **nicht** eingerichtet (deferred — Polling reicht).

Heißt: Tim muss Jarvis NICHT sagen "ich hab X erledigt" — er hakt einfach in Todoist ab.

## Vault-Spiegelung

Erledigte Tasks landen NICHT automatisch im Vault. Wenn ein erledigter Task substantiell für ein Projekt ist (z.B. "PR gemerged", "Vogt-Mail raus"), aktualisiere die zuständige Projekt-Note (`projekte/...`) als Logbuch-Eintrag.

**Lerneinheiten-Pipeline** ist Spezialfall: `vorlauf.py` → Todoist (Modul-Sub-Project), Tim hakt ab → `sync_back.py` setzt `[ ]` → `[x]` in `einheiten.md` → `pace.py` rechnet drift neu. Siehe [[referenz/todoist]] für Details.

## Output-Format für Telegram

`jt pending` ohne `--json` gibt eine kompakte Sicht aus, gruppiert nach Project-Pfad:

```
## Uni / 🔬 Thermo
  ▢ Material-Sichtung & Goldgrube zählen 🔽 📅 05.05.  ·M3PWRJ4G
  ▢ Diagnose-Klausur H2025 unter Zeitdruck rechnen 🔽 📅 05.05.  ·2677x6GG

## Work / EDP
  ▢ PR-Review fertig ⏫ 📅 30.04.  ·a3f9c2GG
```

Die `·UID-Kurzform` (letzte 8 Zeichen der Todoist-Task-ID) ist nicht für `jt done` nutzbar — `jt done` braucht die volle Task-ID. Aus dem `--json`-Output ziehen.

## Labels

Vorhandene Labels (vom System, nicht erweitern ohne Rücksprache):
- Energie: `deep`, `shallow`
- Zeit: `5min`, `30min`, `90min`
- Kontext: `home`, `campus`, `errand`, `anywhere`
- Source: `from-jarvis` (automatisch bei `jt add`)

## Filter (User-Sicht in der Todoist-App)

8 gespeicherte Filter — Tim sieht die in der App-Sidebar:
🎯 Heute Fokus, 🧠 Deep Work, ⚡ 5-Min, 🍞 Heute Einkauf, 🎓 Uni 7-Tage, 💼 Arbeit aktiv, 🗂 Inbox-Stale, ⚠ Drift-Alarm.

## Don'ts

- **Keine Mass-Inserts** ohne Approval. Wenn ein Lernplan-Update >10 Tasks erzeugen würde → vorher Tim fragen.
- **Keine Module umbenennen / Sub-Projects löschen** — bricht das `vault_to_todoist`-State-Mapping.
- **Keine Tasks löschen, die Tim selbst angelegt hat** — Erkennen am fehlenden `from-jarvis`-Label.
- **Keine Recurring-Tasks reschedulen** — Todoist „skipt" still die Iteration → Pace-Tracker zählt falsch.
- **Areas (`Work`/`Uni`/`Privat`) NICHT als `add`-Target** — immer Sub-Project nutzen.

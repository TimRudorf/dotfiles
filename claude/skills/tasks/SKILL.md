---
name: tasks
description: Tims ToDo-System (Nextcloud Tasks ↔ Apple Reminders). Use this skill when Tim wants to view, add, complete, or check his tasks across Inbox/Arbeit/Uni/Privat/Haushalt/"Wartet auf" lists. Trigger keywords: "task", "todo", "aufgabe", "erledigt", "was muss ich noch", "trag ein", "merk dir", "neue aufgabe", "hak ab", "/tasks". Apple Reminders auf iPhone ist Tims primäres UI; dieser Skill ist Jarvis' CRUD-Zugang via CalDAV.
---

# tasks — Nextcloud Tasks Bridge

Tims persönliches ToDo-System. **Apple Reminders auf iPhone ist die primäre UI**, syncht via CalDAV auf Tims Nextcloud (`cloud.timrudorf.de`). Jarvis liest/schreibt dieselben Listen via CalDAV.

## Listen (fix)

| Liste | Wofür |
|---|---|
| Inbox | Uneinsortiert — wenn Tim den Kontext nicht klar mitgibt |
| Arbeit | EDP-Werkstudent + Rettungsdienst |
| Uni | TU Darmstadt Studium |
| Privat | Persönliches, Hobbys, Reisen |
| Haushalt | Einkauf, Reparieren, Putzen, Wohnung |
| Wartet auf | Delegiert / blockiert / in Schwebe |

Keine neuen Listen ohne Rücksprache mit Tim. Wenn ein Task in keine passt → Inbox.

## Tool

CLI: `/workspace/jarvis-tasks/jt` (alias: `jt` falls im PATH). Subkommandos:

```
jt list [--list NAME] [--include-done] [--json]
jt pending [--json]                    alle offenen über alle Listen
jt since <iso-datetime> [--json]       was wurde seit X erledigt (für Status-Loop)
jt add <list> <title> [--due YYYY-MM-DD] [--prio low|med|high] [--note TEXT]
jt done <uid>                          (selten — Tim hakt selber in Reminders ab)
jt lists
```

Vor jedem Aufruf: `set -a; source /opt/stacks/jarvis/.env; set +a` (Container-Env mit `NC_PRIVATE_*`).

## Wann nutzen

- **Tim sagt** "trag ein …", "merk dir …", "neue aufgabe", "task <domain>: …" → `jt add`
- **Tim fragt** "was steht heute an", "was muss ich noch", "/tasks" → `jt pending`
- **Tagesabschluss / Reflexion** "was hab ich heute geschafft" → `jt since <heute-00:00>`
- **Zuordnung der Liste**: aus Tims Wording erkennen (`uni`/`klausur` → Uni; `edp`/`kunde`/`ticket`/`zammad` → Arbeit; `einkauf`/`putzen` → Haushalt; sonst `Privat`; im Zweifel `Inbox`)

## Eingabe-Heuristik (Tim → Task)

Tim spricht meistens unstrukturiert. Parse selbst:

- **Liste** aus Kontext (siehe oben). Bei mehrdeutig: `Inbox`.
- **Due Date** aus relativen Wörtern: "morgen", "übermorgen", "freitag", "nächste woche" → ISO-Datum.
- **Prio** nur wenn Tim sie nennt ("dringend" → high, "irgendwann" → low).
- **Title** kurz halten — Apple Reminders zeigt nur ~50 Zeichen lesbar.
- **Note** optional — wenn Tim Kontext mitgibt der nicht in den Title gehört.

Bei `jt add` mit `--due` ohne Uhrzeit wird automatisch 23:59 gesetzt (gilt als "an dem Tag fällig").

## Status-Loop (kritisch verstehen)

Apple Reminders ist die **primäre Eingabe für Tim**. Wenn Tim einen Task in Reminders abhakt, erfährt Jarvis es nur via CalDAV-Pull — nicht in Echtzeit. Der **Tagesabschluss-Heartbeat** zieht `jt since <heute-00:00>` und bestätigt erledigte Tasks in der Reflexion.

Heißt: Tim muss Jarvis NICHT sagen "ich hab X erledigt" — er hakt einfach in Reminders ab.

## Vault-Spiegelung

Erledigte Tasks landen NICHT automatisch im Vault. Wenn ein erledigter Task substantiell für ein Projekt ist (z.B. "PR gemerged", "Vogt-Mail raus"), aktualisiere die zuständige Projekt-Note (`projekte/...`) als Logbuch-Eintrag — aber nicht als Task-Mirror.

## Output-Format für Telegram

`jt pending` ohne `--json` gibt eine kompakte Sicht aus, gruppiert nach Liste. Direkt für Telegram nutzbar:

```
## Arbeit
  ▢ PR-Review fertig ⏫ 📅 30.04.  ·a3f9c2
  ▢ Sprintplanung vorbereiten 📅 02.05.  ·b7d1e8
```

Die `·UID-Kurzform` reicht zur Re-Identifikation — bei `jt done` gibt Tim die Kurzform an, der Helper matcht via Prefix.

## Don'ts

- **Keine Mass-Inserts** ohne Approval. Wenn ein Lernplan-Update 20 Tasks erzeugen würde → vorher Tim fragen.
- **Keine Listen löschen / umbenennen** — die sind iPhone-gemountet, Änderungen brechen Tims Setup.
- **Keine Tasks in `studium`/`personal`/`rettungsdienst`-Kalender schreiben** — das sind Termin-Kalender, keine Task-Listen.
- **Keine Geo-/Location-Felder** setzen — werden via CalDAV nicht sauber übertragen.

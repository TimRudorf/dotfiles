---
name: regeln-kalender
description: Tims Regeln für Kalender- und Terminarbeit: Konflikte selbst lösen, Termine mit fremden Teilnehmern nie anfassen, Uhrzeit vor jedem Heute-Slot prüfen, Outlook-ICS immer vorher ziehen, die fünf Operations-Quellen kohärent halten. Nutzen bei jeder Termin-, Tagesplan- oder Kalenderoperation.
---

# Kalender — Tims Regeln

Diese Regeln galten bis 2026-08-26 als "universell" und lagen in `CLAUDE.md`.
Sie greifen aber nur in diesem Zusammenhang — deshalb stehen sie hier und
kosten nichts, solange der Zusammenhang nicht vorliegt.

## planer-eigenstaendig

Kalenderkonflikte selbst lösen, Tim per Notification informieren

## cross-system-kohaerenz

5 Operations-Quellen (routines.json/wochenplan/iCloud-Kalender/Todoist/Outlook-ICS) aktiv synchron halten: beim Heartbeat via kohaerenz.py UND sofort nach jeder selbst vorgeschlagenen Plan-Änderung (Kalender/Tasks/Vault updaten, nicht nur im Chat sagen)

## aktuelle-uhrzeit-pruefen

vor jedem Heute-Slot `date` prüfen, DTSTART muss `now()+Rüstzeit` sein, keine vergangenen Slots anlegen

## arbeit-ics-immer-pullen

vor JEDER Termin-/Tagesplanung Outlook-ICS (`WORK_CAL_ICS`) pullen, auch an "kein Arbeiten"-Tagen. Outlook ist authoritative, Tim entscheidet pro Termin einzeln was er wahrnimmt — was im Feed steht, ist gesetzt

## kalender-attendee-events-tabu

Events mit fremden Attendees (ATTENDEE ≠ Tim) sind read-only: nie autonom löschen/verschieben/überschreiben — auch nicht durch Routinen, Tag+7, kohaerenz.py oder Dedup-Heuristik. Bei Konflikt weicht IMMER der Block ohne Attendees, sonst request_approval. Volltext: [[tim/feedback/kalender-attendee-events-tabu]]

---

Volltexte mit Warum und Wie liegen im Vault unter `tim/feedback/<slug>.md`.
Bei Grenzfällen dort nachlesen statt raten.

---
name: routinen
description: Umgang mit Jarvis' zeitgesteuerten Routinen — welche es gibt, anlegen, ändern, Zeit verschieben, an- und abschalten, löschen, einzeln testen, ausrollen und nachsehen warum eine nicht lief. Nutzen bei allem, was mit wiederkehrenden Läufen zu tun hat: "bau mir eine Routine", "jeden Morgen soll Jarvis …", "schalt das ab", "verschieb das auf 7 Uhr", "warum kam heute kein Briefing", "welche Routinen laufen eigentlich".
---

# Routinen

Eine Routine ist **eine Datei plus eine Cron-Zeile**. Mehr nicht.

```
~/dev/jarvis/                     Mac (Repo TimRudorf/jarvis)
/opt/stacks/jarvis-next/          VM (Klon)

routines/<name>.md    was sie tut          } gemountet — Restart genügt
crontab               wann sie läuft       }
tasks/<name>.py       optional: Python für alles Mechanische
workspace/            Entrypoint & Skripte  → Änderungen brauchen einen NEUBAU
```

Ausgeführt wird sie so:

```
supercronic → run-routine <name> → claude -p "<routines/name.md> + _gemeinsam.md"
                                        └→ SendMessage an die Sitzung "jarvis"
```

---

## Bestand ansehen

```bash
cd ~/dev/jarvis
grep -vE '^\s*#|^\s*$' crontab          # was wann läuft
ls routines/                             # was es gibt
```

Beides muss zusammenpassen. Eine Prompt-Datei ohne Cron-Zeile läuft nie und
fällt niemandem auf:

```bash
grep -oE 'run-routine [a-z-]+' crontab | awk '{print $2}' | while read r; do
  [ -f "routines/$r.md" ] || echo "Cron-Zeile ohne Datei: $r"
done
for f in routines/*.md; do b=$(basename "$f" .md)
  case "$b" in _*|smoketest) continue;; esac
  grep -q "run-routine $b" crontab || echo "Datei ohne Cron-Zeile: $b"
done
```

## Zeit verschieben

Nur die Cron-Zeile. `Minute Stunde Tag Monat Wochentag`:

```cron
12 6  * * *    täglich 6:12
33 21 * * 0    sonntags 21:33          (0 = Sonntag)
7  8  * * 1-5  werktags 8:07
```

**Keine glatten Minuten.** `:00` und `:30` sind die Zeitpunkte, auf die alle
Welt feuert — `12 6` statt `0 6`.

## Abschalten und wieder anschalten

Cron-Zeile auskommentieren, Datei bleibt liegen:

```cron
# 12 6 * * *   /usr/local/bin/run-routine nachrichten-briefing   # pausiert 26.08.
```

Datum und Grund dazuschreiben — sonst weiß in drei Wochen niemand mehr, ob das
Absicht war. Anschalten heißt: `#` weg.

## Anlegen

`routines/<name>.md`, benannt nach der Sache:

```markdown
# <Titel>

<Ein Satz: was diese Routine bezweckt.>

Bestimme Datum und Wochentag selbst mit `date` (Europe/Berlin) — verlass dich
nicht auf Angaben im Prompt.

## Vorgaben

Es gelten zusätzlich die gemeinsamen Vorgaben aus `_gemeinsam.md`.

Ist nichts Berichtenswertes passiert: **nichts schicken.**

## Ablauf

1. …
```

`_gemeinsam.md` hängt `run-routine` **automatisch** an — Vault-Check,
Zustellung und Dry-Run stehen dort und gehören nicht in die einzelne Routine.

Der Prompt muss **prüfbar** sein: „Kalender aufräumen" ist keine Anweisung,
„Events ohne Attendees, die mit einem Outlook-Termin kollidieren, kürzen" ist
eine. Und was schiefgeht, gehört in die Meldung.

**Erst testen, dann den Cron-Eintrag dazu.**

## Ändern

Datei bearbeiten. Die Git-Historie zeigt, was sich wann geändert hat — deshalb
gehören Routinen ins Repo und nicht in ein Wiki.

## Löschen

Cron-Zeile **und** Datei entfernen, ein Commit. Mit aufräumen: der Python-Helfer
in `tasks/`, sein Test, der Eintrag in `README.md`, Verweise aus anderen
Routinen. Was übrig bleibt und nichts mehr steuert, ist ein Defekt und kein
neutraler Zustand.

## Testen

```bash
ssh jarvis-vm 'docker exec -u claude jarvis run-routine <name>'
```

Läuft sofort, unabhängig von der Uhrzeit. `run-routine smoketest` prüft die
Kette (Vault erreichbar, Zustellung funktioniert), ohne etwas zu tun.

## Ausrollen

```bash
cd ~/dev/jarvis && git add -A && git commit -m "…" && git push
ssh jarvis-vm 'cd /opt/stacks/jarvis-next && git pull && docker compose restart jarvis'
```

Nur bei Änderungen unter `workspace/`:

```bash
ssh jarvis-vm 'cd /opt/stacks/jarvis-next && git pull && docker compose up -d --build'
```

## Warum lief sie nicht?

In dieser Reihenfolge:

```bash
# 1. Hat supercronic sie überhaupt gesehen?
ssh jarvis-vm 'docker logs jarvis 2>&1 | grep -i "<name>\|crontab"'

# 2. Läuft der Container, laufen die Sitzungen?
ssh jarvis-vm 'docker exec -u claude jarvis tmux ls'

# 3. Von Hand nachstellen — die Ausgabe zeigt den Fehler
ssh jarvis-vm 'docker exec -u claude jarvis run-routine <name>'
```

Kam die Meldung nicht an, obwohl der Lauf durchlief: die Zielsitzung `jarvis`
muss existieren (`tmux ls`), sonst geht die Zustellung ins Leere.

---

## Fallen

> [!warning] Nie um eine Bestätigung bitten
> Der Routinen-Prozess ist Sekunden nach dem Senden beendet, seine Adresse tot.
> Bittet die Meldung um eine Antwort, sucht die Empfängersitzung eine
> „Nachfolgesitzung" und schreibt dorthin — die antwortet ihrerseits. So lief
> am 26.08.2026 stundenlang ein Ringverkehr zwischen drei Sitzungen, ausgelöst
> von einer einzigen Testnachricht. Die Meldung ist eine **Mitteilung, keine
> Frage.**

> [!warning] Änderungen unter workspace/ brauchen einen Neubau
> Entrypoint, `run-routine` und `ensure-sessions` liegen **im Image**. Ein
> `restart` nimmt sie nicht mit — das kostet sonst eine Viertelstunde
> Fehlersuche an einem Fix, der längst geschrieben ist.

> [!warning] Lange Läufe abfangen
> Externe Aufrufe (IMAP, HTTP, große Pipes) mit `timeout 30s …` umschließen.
> Ein hängender Unterprozess hält die ganze Routine auf.

> [!tip] Mechanisches gehört nach Python
> Was deterministisch ist — Feeds ziehen, Dateien bauen, hochladen — gehört in
> ein Skript unter `tasks/` und wird von der Routine nur aufgerufen. Der Prompt
> ist fürs Urteilen da, nicht fürs Rechnen. Ein Skript ist testbar, ein Prompt
> nicht.

> [!tip] Eine eigene Routine oder eine bestehende erweitern?
> Eigenständig, wenn sie **eigenständig scheitern können soll** — dann sieht
> Tim genau, was ausgefallen ist. Sonst erweitern.

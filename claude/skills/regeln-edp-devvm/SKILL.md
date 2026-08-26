---
name: regeln-edp-devvm
description: Tims Regel zur EDP-Dev-VM als einziger harter geteilter Ressource: vor jedem verändernden Kommando exklusiv sperren, bei Belegung warten statt überschreiben, nach dem Kompilieren den Branch gegenprüfen. Nutzen bei jedem edp-ctrl-dev-Kommando (compile, test, service).
---

# Edp Devvm — Tims Regeln

Diese Regeln galten bis 2026-08-26 als "universell" und lagen in `CLAUDE.md`.
Sie greifen aber nur in diesem Zusammenhang — deshalb stehen sie hier und
kosten nichts, solange der Zusammenhang nicht vorliegt.

## dev-vm-exklusiv-belegen

die **Dev-VM ist die einzige harte geteilte Ressource** zwischen parallelen Sessions. `edp-ctrl dev compile` setzt sie per `reset --hard` auf den Branch der **aufrufenden** Session → zwei gleichzeitige Läufe erzeugen eine **stille Fehlmessung** (Session A prüft gegen den Code von B, nichts wird rot). Vor dem ersten verändernden Kommando `C:\vm.lock` per **check-and-set in einem** SSH-Aufruf setzen, danach **immer** freigeben — auch im Abbruchpfad; belegt → **warten, nie überschreiben**; nach `compile` den Branch im Ausgabekopf gegenprüfen. Lock brauchen `compile`, `test` (trotz des Namens destruktiv) und `service start|stop`; `log`/`compilelog` **dürfen ihn nicht halten** (blockieren bis Ctrl-C). Robuster als jeder Lock: vorab genau **eine** Session als VM-Session benennen, alle anderen arbeiten VM-frei. Das Werkzeug erzwingt nichts — die Disziplin trägt die Regel. Volltext: [[tim/feedback/dev-vm-exklusiv-belegen]]

---

Volltexte mit Warum und Wie liegen im Vault unter `tim/feedback/<slug>.md`.
Bei Grenzfällen dort nachlesen statt raten.

---
name: transcribe
description: Arbeitet die Transkriptions-Queue ab — alle vom Container (moodle_sync.py) erkannten, noch nicht transkribierten Vorlesungs-/Übungsaufzeichnungen aus den <modul>/transkripte/_pending.json im Vault. Der Mac-Gegenpart zur Container-Detection: Container erkennt + meldet per Telegram, am Mac wird mit Tim (Login/Re-Auth möglich) transkribiert. Use when Tim "/transcribe" tippt oder "die neuen Aufzeichnungen transkribieren" / "Queue abarbeiten" sagt. Trigger keywords - /transcribe, transkribieren, neue Aufzeichnungen, Transkriptions-Queue, pending transkribieren.
disable-model-invocation: true
argument-hint: "[--dry] [--module <slug> …] [--limit N]"
---

# transcribe — Transkriptions-Queue abarbeiten (Mac)

Drainiert die `_pending.json`-Queues, die `moodle_sync.py` im Container befüllt (neue
Aufzeichnungen → Telegram-Ping „N neue Aufzeichnung(en) … am Mac `/transcribe`"). Tim
geht an den Mac, tippt `/transcribe`, wir machen es zusammen — inkl. SSO-Login, falls
ein Cookie abgelaufen ist (Re-Auth geht NUR am Mac, headed).

Architektur & Hintergrund: [[projekte/lernplan/vorlesungs-transkription/konzept]] §6 Phase B
+ [[projekte/lernplan/vorlesungs-transkription/pipeline-bugfix-pickup]]. Die eigentliche
ASR-Maschinerie (Download/Chunking/gpt-4o-transcribe/Frontmatter/Verify) liegt im Skill
[[lecture-transcribe]] — dieser Skill ist nur der Queue-Treiber drumherum.

## Voraussetzungen
- Env: `OPENAI_API_KEY_PRIVATE` (Uni = privater Kontext)
- Tools: `yt-dlp`, `ffmpeg`, `ffprobe`, `playwright-cli`, `curl`, `python3`
- Datei: `~/.claude/skills/lecture-transcribe/transcribe_pending.py` (+ `transcribe_bulk.py`, `transcribe.py`) · `~/Documents/uni/lecture-tools/cookies.txt` · pro Modul `<modul>-terms.txt`
- Vault auf `origin/main` (Container hat die Queue evtl. gerade frisch befüllt) → vorab `git -C ~/Documents/jarvis-wiki pull`.

## Schritt 1 — Queue sichten (immer zuerst)

```bash
set -a; source ~/.env; set +a
cd ~/.claude/skills/lecture-transcribe
python3 transcribe_pending.py --dry
```

Zeigt pro Modul die offenen Aufzeichnungen mit `source`/`auth`. Tim kurz berichten, was
ansteht (Anzahl + Module). Bei 0 offenen → fertig, melden, Topic ggf. schließen.

## Schritt 2 — Cookies sicherstellen (DEFAULT HEADLESS)

`transcribe_pending.py` macht selbst einen Vorabcheck:
- **Panopto** (LTI-Aufzeichnungen) → Test gegen eine stabile Session.
- **CAS** (moodleload/Camtasia) → nur falls solche Einträge in der Queue sind.

Bricht es mit `🔑 …-Cookie abgelaufen` ab (Exit 3 = Panopto, 4 = CAS), dann **headed**
neu einloggen — Tim macht das aktiv mit:
- **Panopto:** SSO über einen `launch.php`-LTI-Link öffnen (siehe `lecture-transcribe/reference.md` → „Cookie-Refresh").
- **CAS:** headed auf eine **moodleload-URL** navigieren (NICHT nur Moodle — CAS ≠ SAML!), Tim loggt sich ein → `state-save` → `cookies.txt`.

Danach `/transcribe` einfach erneut starten (idempotent — nichts doppelt).

> [!important] Re-Auth nur auf echten Auth-Fehler, nie prophylaktisch headed öffnen.

## Schritt 3 — Abarbeiten

```bash
set -a; source ~/.env; set +a
cd ~/.claude/skills/lecture-transcribe
python3 transcribe_pending.py                 # alle offenen
# optional: --module modern-firm international-economics   |   --limit 3
```

Pro Aufzeichnung: Quelle auflösen (LTI→Panopto-GUID headless; moodleload/Camtasia→Direkt-MP4;
Legacy-`url`→Redirect-Resolve) → Download → 16 kHz mono mp3 → `transcribe.py` (`--lang` je
Modul, `<modul>-terms.txt`) → Frontmatter (`cmid` + `quelle_url` → damit `moodle_sync` den
Eintrag künftig als erledigt erkennt) → Verify. **Erfolg → Eintrag fliegt aus der Queue**;
FAIL bleibt pending (Retry beim nächsten Lauf). Commit/Push des Vaults passiert am Ende.

**Erste Welle live prüfen:** Beim ersten Durchlauf eines neuen Moduls die Sprache + ein
Transkript stichprobenartig ansehen (falsche Sprache → Prompt-Echo, siehe reference.md).

## Schritt 4 — Berichten

- Knapp melden: wie viele OK / SUSPECT / FAIL, welche Module.
- SUSPECT/FAIL benennen (chars/min-Auffälligkeit oder Download-Fehler) und ob ein erneuter
  Lauf (nach Re-Auth) sinnvoll ist.
- Bei neuem Modul ohne `<modul>-terms.txt`: kurz anbieten, aus den Kontrollfragen/Stichwörtern
  eine Fachbegriff-Liste zu bauen (verbessert Eigennamen deutlich).
- `transkripte/INDEX.md` der betroffenen Module via `build_indexes.py` aktualisieren, wenn neue
  Transkripte dazukamen.

## Verwandt
- [[lecture-transcribe]] (Tooling/manueller Einzel-Modus) · [[projekte/lernplan/vorlesungs-transkription/konzept]] · `moodle_sync.py` (Container-Detection, docker-compose-Repo)

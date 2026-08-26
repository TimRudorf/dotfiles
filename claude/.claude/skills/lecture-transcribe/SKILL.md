---
name: lecture-transcribe
description: Transkribiert TU-Darmstadt-Panopto-Vorlesungsaufzeichnungen (Moodle-LTI → Panopto → Audio → gpt-4o-transcribe) zu timestamped Markdown-Transkripten im Vault unter projekte/lernplan/<modul>/transkripte/. Dienen als Primärquelle bei der Lerneinheit-Erstellung — v.a. für Kontrollfragen, deren Antwort nur verbal in der VL fällt. Use when Tim Vorlesungen/Übungen transkribieren will, einzelne oder im Bulk pro Modul. Trigger keywords - transkribieren, Vorlesung transkribieren, Aufzeichnung, Panopto, Transkript, /lecture-transcribe.
disable-model-invocation: true
argument-hint: <modul-slug> [all|<cmid>] [--seg=300]
---

# Lecture-Transcribe — Panopto-Aufzeichnungen ins Vault transkribieren

Holt TU-Panopto-Aufzeichnungen (eingebunden per Moodle-LTI), extrahiert Audio und transkribiert mit **gpt-4o-transcribe** zu timestamped Markdown im Vault. Konzept + Architektur: [[projekte/lernplan/vorlesungs-transkription/konzept]].

## Voraussetzungen
- Env: `OPENAI_API_KEY_PRIVATE` (Uni = **privater** Kontext; EDP-Kontext nutzt `_WORK`, siehe [[referenz/credentials]])
- Tools: `yt-dlp`, `ffmpeg`, `python3`, `playwright-cli`, `curl`
- Datei: `transcribe.py` (chunk-weise ASR, `--lang`, Retry/Backoff, Prompt-Echo-Stripper) · für Bulk: `transcribe_bulk.py` + `build_indexes.py` (alle in diesem Skill-Verzeichnis) · `~/Documents/uni/lecture-tools/cookies.txt` (SSO-Session) · pro Modul `<modul>-terms.txt`
- Projekt: `~/Documents/uni/moodle-mirror/<modul>/` (Mirror) + Course-ID aus `projekte/lernplan/<modul>/moodle-snapshot.json`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Schritt 1: Auth sicherstellen — DEFAULT HEADLESS

Cookies liegen als Netscape-`cookies.txt` (`~/Documents/uni/lecture-tools/cookies.txt`). **Erst Gültigkeit testen** an einer beliebigen bekannten Panopto-Session:

```bash
yt-dlp --cookies ~/Documents/uni/lecture-tools/cookies.txt --skip-download --no-warnings \
  --print "%(title)s" "https://tu-darmstadt.cloud.panopto.eu/Panopto/Pages/Viewer.aspx?id=<bekannte-GUID>"
```

- **Gültig** (Titel kommt) → weiter, alles headless.
- **Abgelaufen** (Auth-Fehler / leer) → Cookie erneuern. **Nur hier** ist ein sichtbares Fenster erlaubt:
  - **Am Mac:** Tim benachrichtigen, dann headed SSO öffnen, Tim loggt sich ein, danach State + cookies.txt neu schreiben (siehe `reference.md` → „Cookie-Refresh").
  - **Im Container/Headless-Kontext:** **kein** Browser möglich → `mcp__bridge__notify_user` („Panopto-Login abgelaufen, bitte am Mac neu einloggen"), Aufgabe in `pending`-Queue, abbrechen. Re-Auth passiert ausschließlich am Mac.
- **Niemals** prophylaktisch headed öffnen — nur auf echten Auth-Fehler.

> [!warning] Direkt-Downloads (moodleload) brauchen CAS — SEPARAT prüfen!
> `moodleload.hrz.tu-darmstadt.de` (direkte MP4/`.html`) nutzt **CAS-Login**, getrennt vom Panopto-/Moodle-Login (kurzlebig, läuft im Bulk ab). Vor Direkt-Downloads zusätzlich testen:
> ```bash
> curl -s -L -b cookies.txt "<moodleload .mp4>" -o /dev/null -w "%{http_code} %{size_download} %{content_type}\n"  # erwartet: 200 <viele> video/mp4
> ```
> Bei `text/html`/~4346b → Cookie tot → headed Re-Auth **auf eine moodleload-URL** (nicht nur Moodle!). Details: `reference.md` → „CAS ≠ SAML".

## Schritt 2: Aufzeichnungs-Liste des Moduls beschaffen

Benötigt wird die Liste der Aufzeichnungs-Module der Moodle-Kursseite (`course/view.php?id=<COURSE>`) im Format:

```json
[{"cmid": "1630442", "titel": "VO 01 Messkette", "typ": "VO"}, {"cmid": "1630448", "titel": "Aufzeichnung VO 02", "typ": "VO"}]
```

> [!important] Einbettung ist HETEROGEN — nicht nur LTI! (siehe `reference.md` → „Kursformate & Video-Einbettung")
> - **Kursformat beachten:** `topics` (Basisseite), `onetopic` (`?section=N`), **`tiles` (`course/section.php?id=<SID>`)** — bei onetopic/tiles **alle Sections fetchen**, sonst fehlen Videos.
> - **Pro Section sammeln:** `mod/lti` (→Panopto-GUID), `mod/url`/`mod/resource` (→oft direkte `moodleload`-MP4), **`mod/page`-Inhalte** (listen oft `.html`/`.mp4`-Aufzeichnungen), `.html`-Camtasia-Wrapper (→Geschwister-`.mp4`).
> - **Source of Truth = Moodle-Kursseite**, nicht der Panopto-Katalog (Alt-Semester-Rauschen).

- `mod/lti`-Links → Panopto; `mod/url`/`mod/resource`/`mod/page` auflösen (`&redirect=1`) → Medien-Ziele behalten. Dedupliziert, mit Titel.
- Scope-Default: **alles** (VO + UE + Sonder + direkte MP4/`.html`), außer Tim schränkt ein.
- Bei `<cmid>`-Argument: nur diese eine Aufzeichnung. Bei `all`: ganze Liste. **Für ganze Module/alle Module → Bulk via `transcribe_bulk.py`** (Schritt „Bulk" unten).

## Schritt 3: Pro Aufzeichnung — Resolve + Download (headless)

Für jede cmid (idempotent: existiert das Ziel-Transkript schon, überspringen):

```bash
# cmid → Panopto-GUID (headless Browser, gespeicherte Cookies)
playwright-cli -s=tuda open --browser=chromium --persistent "https://moodle.tu-darmstadt.de/mod/lti/launch.php?id=<CMID>&triggerview=0" >/dev/null 2>&1
GUID=$(playwright-cli -s=tuda eval "() => (location.href.match(/Embed\.aspx\?id=([0-9a-f-]{36})/i)||[])[1] || 'NONE'" 2>/dev/null | grep -A1 Result | tail -1 | tr -d '"')
# Audio (kleinster Stream → 16 kHz mono mp3). Format NIE hartkodieren → -f worst
yt-dlp --cookies ~/Documents/uni/lecture-tools/cookies.txt -f worst -x --audio-format mp3 \
  --postprocessor-args "-ar 16000 -ac 1" -o "~/Documents/uni/moodle-mirror/<modul>/aufzeichnungen/<slug>.%(ext)s" \
  --no-warnings "https://tu-darmstadt.cloud.panopto.eu/Panopto/Pages/Viewer.aspx?id=$GUID"
```

Hinweis: `open --persistent` ohne `--headed` läuft headless. `<slug>` = normalisierter Titel (z.B. `VO01`, `UE03`).

## Schritt 4: Transkribieren (gpt-4o-transcribe)

Pro-Modul-Fachbegriffe in `~/Documents/uni/lecture-tools/<modul>-terms.txt` (für Sensortechnik existiert `st-terms.txt`; bei neuem Modul aus den Kontrollfragen/Stichwörtern erzeugen).

```bash
set -a; source ~/.env; set +a   # OPENAI_API_KEY_PRIVATE laden
python3 ~/.claude/skills/lecture-transcribe/transcribe.py \
  "<audio>.mp3" "<VAULT>/projekte/lernplan/<modul>/transkripte/<slug>.md" \
  --seg 300 --lang de --title "<slug> <titel>" --prompt-file ~/Documents/uni/lecture-tools/<modul>-terms.txt
```

Das Script splittet in 300-s-Chunks (Zeitmarken + 25-MB-Limit), verkettet Kontext (Fachbegriffe + Tail des Vor-Chunks) und schreibt inkrementell — bei Abbruch geht nichts verloren. **`--lang` korrekt setzen** (`de`/`en`) — falsche Sprache erzeugt Prompt-Echo (siehe `reference.md`). Retry/Backoff gegen 429 + Echo-Stripper sind eingebaut.

**Direkt-MP4 (moodleload) statt Panopto:** kein yt-dlp-`-f worst`, sondern `curl -s -L -b cookies.txt "<url>" -o raw.mp4` (folgt CAS) → `ffmpeg -i raw.mp4 -ar 16000 -ac 1 <slug>.mp3`. `.html`-Camtasia → vorher `.html`→Geschwister-`.mp4` ableiten.

## Schritt 5: Frontmatter + Vault-Ablage

Ans erzeugte Transkript oben Frontmatter setzen (idempotenz-/Quellen-Nachweis):

```yaml
---
type: transkript
modul: <modul>
einheit: <slug>
panopto_id: <GUID>
cmid: <CMID>
dauer: <MM:SS>
modell: gpt-4o-transcribe
transkribiert_am: <YYYY-MM-DD>
quelle: "Moodle LTI cmid <CMID> → Panopto"
---
```

- Audio (mp3) **nicht** ins Vault (liegt im Mirror). Nur das Markdown-Transkript ins Vault → wird via Vault-Hook auto-committet.
- Bei großem Modul optional `transkripte/INDEX.md` mit Tabelle (slug · dauer · Datum).

## Schritt 6: LE-Verknüpfung

In der Modul-`strategie.md` (Goldquellen) `transkripte/` als Quelle nennen. Bei LE-Erstellung gilt: Transkript ist **Primärquelle neben Folien + KF-PDF** — Anker-Format `Transkript <slug> @ [MM:SS]` (siehe [[tim/feedback/plan-quellen-tiefenanalyse]]).

## Bulk (ganze Module / alle Module)

Für „transkribiere alles" → **`transcribe_bulk.py`** statt manuell Schritt 3–6:
```bash
set -a; source ~/.env; set +a
cd <skill-dir-oder-lecture-tools>
python3 transcribe_bulk.py --dry                 # Queue prüfen
python3 transcribe_bulk.py --per-module 1        # je 1 Item/Kurs testen (Sprache/Pfade verifizieren!)
python3 transcribe_bulk.py --workers 5           # voller Lauf (idempotent, self-verify, Vault-Commit alle 10)
python3 build_indexes.py                         # transkripte/INDEX.md + Goldquellen je strategie.md
```
- Liest `full_manifest.json` (Harvest: `{modul:{lti,media}}`) + `guids.json` (cmid→GUID). `LANG`-Map im Script (en-Module!).
- **Self-verify** → `bulk_status.json` (OK/SUSPECT/FAIL nach chars/min + `[FEHLER]`-Marker). FAILs werden beim erneuten Lauf automatisch retried.
- **Cookie-Ablauf mitten im Lauf** = häufigster Fehler (alle Direkt-Downloads → `curl-DL (4346b)`): Re-Auth (Schritt 1) + Bulk erneut starten. Erste Welle live-QC + Sprache prüfen, dann laufen lassen.
- Verlauf/Pickup einer langen Session: `[[projekte/lernplan/vorlesungs-transkription/bulk-status-pickup]]`.

Abschließend `skill-optimize` mit `lecture-transcribe` aufrufen.

# lecture-transcribe — Referenz

## URL-Muster (TU Darmstadt)
- Moodle-Kursseite: `https://moodle.tu-darmstadt.de/course/view.php?id=<COURSE>`
- LTI-Modul: `https://moodle.tu-darmstadt.de/mod/lti/view.php?id=<CMID>` (Anzeige) / `.../launch.php?id=<CMID>&triggerview=0` (LTI-POST → Panopto)
- Panopto-Viewer: `https://tu-darmstadt.cloud.panopto.eu/Panopto/Pages/Viewer.aspx?id=<GUID>`
- Panopto-Host: `tu-darmstadt.cloud.panopto.eu`. yt-dlp-Extraktoren: `Panopto`, `PanoptoList`, `PanoptoPlaylist`.

## Auth-Test-GUID (für Schritt 1)
Sensortechnik VO00 = `64311577-06c3-458f-a6e2-af3801217dfb` (stabil, zum Cookie-Gültigkeitstest).

## Cookie-Refresh (NUR am Mac, NUR bei Expiry, headed)
```bash
# 1) headed SSO öffnen — Tim loggt sich ein (Username/Passwort + ggf. 2FA)
playwright-cli -s=tuda open --browser=chromium --headed --persistent \
  "https://moodle.tu-darmstadt.de/mod/lti/launch.php?id=1630438&triggerview=0"
# 2) nach Login: warten bis location auf Embed.aspx?id=… steht (= Panopto erreicht)
# 3) State sichern + nach Netscape cookies.txt konvertieren
playwright-cli -s=tuda state-save ~/Documents/uni/lecture-tools/tuda-state.json
python3 - <<'PY'
import json,time
d=json.load(open('/Users/timrudorf/Documents/uni/lecture-tools/tuda-state.json'))
with open('/Users/timrudorf/Documents/uni/lecture-tools/cookies.txt','w') as f:
    f.write('# Netscape HTTP Cookie File\n')
    for c in d.get('cookies',[]):
        dom=c['domain']; inc='TRUE' if dom.startswith('.') else 'FALSE'; sec='TRUE' if c.get('secure') else 'FALSE'
        exp=int(c.get('expires',0)) if c.get('expires',-1)>0 else int(time.time())+86400
        f.write('\t'.join([dom,inc,c.get('path','/'),sec,str(exp),c['name'],c['value']])+'\n')
print('cookies.txt aktualisiert')
PY
playwright-cli -s=tuda close   # zurück zu headless-Default
```
Die SSO-Session bleibt im persistenten Profil; künftige headless-Läufe (`open --persistent` ohne `--headed`) nutzen sie weiter. cookies.txt enthält Session-Tokens → **niemals ins Vault/Git**.

> [!warning] CAS ≠ SAML — zwei getrennte Logins! (verifiziert 2026-05-26)
> `moodleload.hrz.tu-darmstadt.de` (direkte MP4s / Camtasia-`.html`) authentifiziert über **CAS** (`login.tu-darmstadt.de/idp/profile/cas/login`), **getrennt** vom Moodle-SAML-Login. Ein Moodle-Login allein reicht für moodleload **nicht** — selbst der eingeloggte Browser landet auf der CAS-Maske. Beim Refresh deshalb headed **auf eine moodleload-`.mp4`** navigieren (nicht nur Moodle), damit der CAS-Login passiert:
> ```bash
> playwright-cli -s=tuda open --browser=chromium --headed --persistent \
>   "https://moodleload.hrz.tu-darmstadt.de/FB01-VWL2/SS26_IMF/IMF_VL1/IMF_1/IMF_1.html"
> # Tim loggt sich an der CAS-Maske ein → Seite leitet aufs Video → dann state-save + cookies.txt
> ```
> Der SSO-Cookie ist **kurzlebig** (läuft in einem mehrstündigen Bulk ab!). Panopto-Cookie hält länger und ist unabhängig.

> [!tip] Cookie-Vorabprüfung (vor jedem Direkt-Download-Batch)
> ```bash
> curl -s -L -b cookies.txt "<moodleload .mp4>" -o /dev/null -w "%{http_code} %{size_download} %{content_type}\n"
> ```
> Muss `200 <viele bytes> video/mp4` liefern. Bei `... text/html` oder ~4346 bytes (Login-Seite) → Cookie tot → Re-Auth (oben). Symptom im Bulk: FAILs mit `curl-DL ... (4346b)`.

## Fachbegriff-Prompt pro Modul
`~/Documents/uni/lecture-tools/<modul>-terms.txt` — ein kurzer Kontextsatz + Komma-Liste der Fachbegriffe (aus Kontrollfragen/Stichwörtern). Verbessert die Schreibung von Eigennamen/Fachtermini deutlich. Beispiel `st-terms.txt` (Sensortechnik) existiert bereits.

## Sensortechnik (Course 44595) — cmid-Mapping (Stand 2026-05-26)
| cmid | Titel | typ |
|---|---|---|
| 1630438 | VO 00 Organisatorisches | VO |
| 1630442 | VO 01 Messkette | VO |
| 1630448 | VO 02 | VO |
| 1630462 | VO 03 | VO |
| 1630471 | VO 04 | VO |
| 1630476 | VO 05 | VO |
| 1630484 | VO 06 | VO |
| 1630493 | VO 07 | VO |
| 1630507 | VO 08 | VO |
| 1630517 | VO 09 | VO |
| 1630529 | VO 10 | VO |
| 1630539 | VO 11 | VO |
| 1630540 | VO 11 Teil 2 | VO |
| 1630548 | VO 12 | VO |
| 1630567 | VO 13 Probeklausur | VO |
Dazu UE 01–12 (cmids 1688675, 1630451, 1630474, 1630479, 1630487, 1630496, 1630510, 1630520, 1630535, 1630551 …) + Sonder-Videos (Messunsicherheit I/II 1630454/55, Kraftmessung 1630502, Temperatur 1630524, Durchfluss 1630562) + 23 E-Technik-Grundlagen-Clips (1630580–…). VO01 als „VO01_kurz" (27:36) bereits transkribiert.

## Kursformate & Video-Einbettung — HETEROGEN (verifiziert 2026-05-26, 12 Kurse)
Videos sind **nicht** einheitlich als LTI eingebunden. Beim Harvesten alle Wege abdecken:

**Kursformate (Section-Discovery):**
- `topics` — alle Aktivitäten auf der Basisseite (`course/view.php?id=<C>`). Einfach.
- `onetopic` — Tabs via `course/view.php?id=<C>&section=N`. Basisseite zeigt nur Section 0!
- `tiles` — Kacheln via **`course/section.php?id=<SECTIONID>`** (interne DB-IDs). Basisseite zeigt nur Section 0 → **alle `section.php?id=`-Links der Basisseite fetchen**, sonst werden Videos übersehen.

**Einbettungs-Arten (pro Section):**
- `mod/lti/view.php` → Panopto-Session (cmid→GUID via launch.php). Häufig bei Ingenieurs-Kursen.
- `mod/url/view.php` / `mod/resource/view.php` → oft **direkte MP4** auf `moodleload.hrz.tu-darmstadt.de` (z.B. FB18: `…/FB18_RMR/<…>.mp4`). Titel-unabhängig auflösen (`&redirect=1`) und Ziel prüfen.
- **`.html`-Wrapper (Camtasia)** → die `.html` enthält iframe `…_player.html`; das Video liegt als **Geschwister-`.mp4`** im selben Ordner (`IMF_1.html` → `IMF_1.mp4`). yt-dlp kann die `.html` NICHT → abgeleitetes `.mp4` per `curl -L` (folgt CAS). FB01-VWL2 (Nitsch etc.).
- `mod/page/view.php` → **Page-Inhalt fetchen** (listet oft die `.html`/`.mp4`-Links der Aufzeichnungen, z.B. „Lecture Recordings SSxx").
- **Panopto-Block** (`block_panopto_content`) → meist leerer provisionierter Ordner; ignorieren wenn 0 Sessions.
- CAS-Login-Wrapper-URLs (`…/idp/profile/cas/login?service=<URL>`) → echtes Ziel aus `service=` urldecoden. Boilerplate `Video-Tutorials/start.html` rausfiltern.

**Source of Truth = die Moodle-Kursseite**, NICHT der Panopto-Katalog (voll mit Alt-Semestern/Fremdkursen → Volltextsuche unbrauchbar).

## Sprache pro Modul (`--lang`)
gpt-4o-transcribe braucht den korrekten Sprach-Hint. **Falsche Sprache → Prompt-Echo** (die Terms-Liste wird am Chunk-Anfang zurückgespiegelt). `transcribe.py --lang en|de`; zusätzlich `strip_prompt_echo` als Netz. Englisch-Module bei TU-WiWi häufig (Modern Firm, Int. Economics, DIMM, PPM-Seminar bei Hettrich).

## Bulk-Workflow (`transcribe_bulk.py` + `build_indexes.py`)
Für „alle Aufzeichnungen aller Module": `transcribe_bulk.py` liest `full_manifest.json` (Harvest-Output: `{modul:{lti:[…],media:[…]}}`) + `guids.json` (cmid→GUID), baut die Queue, lädt+transkribiert **parallel (`--workers 5`)**, **idempotent** (existierende/`[FEHLER]`-freie Transkripte übersprungen), **self-verify** (OK/SUSPECT/FAIL nach chars/min + `[FEHLER]`-Marker → `bulk_status.json`), committet Vault alle 10. Panopto via yt-dlp, Direkt-MP4 via `curl -L`→ffmpeg. `--per-module 1` / `--limit N` / `--dry` zum Testen. Danach `build_indexes.py` → `transkripte/INDEX.md` + Goldquellen in `strategie.md`.
**Vor dem Bulk:** Cookie-Vorabprüfung (oben). **Bei Cookie-Ablauf mitten im Lauf:** Re-Auth + `transcribe_bulk.py` erneut (re-läuft nur FAILs).

## Kosten (verifiziert)
gpt-4o-transcribe ≈ $0.006/min → ~$0.35/60-min-VL. **Bulk 2026-05-26: 188 Aufzeichnungen, 210 h Audio, ~$76.** Manche Sessions nur 1080p (~1,8 GB Download). Audio bleibt als 16-kHz-mono-mp3 (~12 MB), Video wird nach Extraktion gelöscht.

## Fallstricke
- Format **nie** hartkodieren (`hls-529` ist sessionspezifisch) → `-f worst` (kleinstes gemuxtes; Panopto hat **keinen** Audio-only-Stream).
- gpt-4o-transcribe: nur `json`/`text`, **keine** nativen Zeitmarken → Chunk-Offsets liefern die Zeitmarken.
- 25-MB-Upload-Limit → Chunking (Default 300 s) hält jeden Chunk klar darunter.
- 5 parallele Worker → 429s möglich → `transcribe.py` hat Retry/Backoff.

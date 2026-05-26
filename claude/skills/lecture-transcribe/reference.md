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

## Kosten
gpt-4o-transcribe ≈ $0.006/min → ~$0.35 / 60-min-VL.

## Fallstricke
- Format **nie** hartkodieren (`hls-529` ist sessionspezifisch) → `-f worst`.
- gpt-4o-transcribe: nur `json`/`text`, **keine** nativen Zeitmarken → Chunk-Offsets liefern die Zeitmarken.
- 25-MB-Upload-Limit → Chunking (Default 300 s) hält jeden Chunk klar darunter.

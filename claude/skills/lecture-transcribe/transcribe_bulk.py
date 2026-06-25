#!/usr/bin/env python3
"""Bulk-Driver: liest full_manifest.json + guids.json, baut die Transkriptions-Queue,
lädt jedes Video (Panopto-GUID via Cookies / direkte MP4-MP3-URL) -> 16kHz mono mp3 im Mirror,
transkribiert via transcribe.py (gpt-4o-transcribe, --lang je Modul, --prompt-file <modul>-terms.txt),
schreibt timestamped Markdown + YAML-Frontmatter ins Vault. Idempotent: existierende Transkripte werden uebersprungen.
"""
import os, re, json, subprocess, sys, datetime, concurrent.futures as cf, argparse, urllib.parse

LT="/Users/timrudorf/Documents/uni/lecture-tools"
VAULT="/Users/timrudorf/Documents/jarvis-wiki"
MIRROR="/Users/timrudorf/Documents/uni/moodle-mirror"
CK=f"{LT}/cookies.txt"
TRANSCRIBE=f"{LT}/transcribe.py"
LANG={"dimm":"en","modern-firm":"en","international-economics":"en","ppm-seminar":"en"}  # Rest: de
TERMS_EXIST=set(os.path.basename(f).replace("-terms.txt","") for f in os.listdir(LT) if f.endswith("-terms.txt"))

def slugify_lti(title, used):
    t=re.sub(r'(?i)\b(aufzeichnung|externes tool|video:?|link/url)\b','',title).strip()
    m=re.search(r'(?i)\b(VO|UE|VL|Übung|Uebung|Vorrechnen\s*Übung|Probeklausur)\s*0*(\d+)',t)
    if m:
        kind=m.group(1).upper().replace("ÜBUNG","UE").replace("UEBUNG","UE").replace("VORRECHNENUE","VUE").replace(" ","")
        base=f"{kind}{int(m.group(2)):02d}"
    else:
        base=re.sub(r'[^A-Za-z0-9ÄÖÜäöü]+','_',t).strip('_')[:40] or "clip"
    s=base; i=2
    while s in used: s=f"{base}_{i}"; i+=1
    used.add(s); return s

def slugify_media(title, target, used):
    path=urllib.parse.unquote(target.split('?')[0])
    fn=os.path.splitext(os.path.basename(path))[0]
    cand=fn or re.sub(r'[^A-Za-z0-9]+','_',title).strip('_')
    cand=re.sub(r'(?i)^vorlesung_?','VO',cand); cand=re.sub(r'(?i)^ubung','UE',cand); cand=re.sub(r'(?i)^uebung','UE',cand)
    cand=re.sub(r'[^A-Za-z0-9ÄÖÜäöü_-]+','_',cand).strip('_')
    sem=re.search(r'SS(\d2|25|26|2[0-9])',path)
    if sem and sem.group(0) not in cand: cand=f"{cand}_{sem.group(0)}"
    s=cand[:50] or "clip"; base=s; i=2
    while s in used: s=f"{base}_{i}"; i+=1
    used.add(s); return s

def transcript_path(modul, slug):
    return f"{VAULT}/projekte/lernplan/{modul}/transkripte/{slug}.md"

def have_transcript(modul, slug):
    p=transcript_path(modul,slug)
    if not (os.path.exists(p) and os.path.getsize(p)>200): return False
    body=open(p,encoding="utf-8",errors="replace").read()
    if "[FEHLER" in body: return False          # fehlerhafte Chunks -> neu machen
    return True

def verify(out_path, dur):
    """Prüft ein fertiges Transkript. -> (status, chars, note). status: OK|SUSPECT|FAIL"""
    if not os.path.exists(out_path): return "FAIL",0,"Datei fehlt"
    body=open(out_path,encoding="utf-8",errors="replace").read()
    # reiner Transkript-Text (ohne Frontmatter/Header/Zeitmarken)
    text=re.sub(r'^---.*?---','',body,count=1,flags=re.S)
    text=re.sub(r'^#.*$','',text,flags=re.M); text=re.sub(r'>.*$','',text,flags=re.M)
    chars=len(text.strip())
    if "[FEHLER" in body: return "FAIL",chars,"enthält [FEHLER]-Marker (API/Netz)"
    # Coverage-Check: letzte Chunk-Zeitmarke (## [HH:MM:SS]) vs Audiodauer. Eine große
    # Lücke = abgeschnittenes Transkript — typisch bei unvollständigem Download: ffprobe
    # liest die volle Dauer aus den mp4-Metadaten, ffmpeg extrahiert aber nur den real
    # heruntergeladenen Teil. Chunks sind 300s, der letzte Chunk-Start liegt bei vollem
    # Transkript also <5min vor dem Ende → Lücke >7min = fehlende Chunks. Sonst würde so
    # ein Torso als OK durchrutschen (chars/Metadaten-Dauer bleibt über der cpm-Schwelle).
    if dur>0:
        tss=re.findall(r'^## \[(\d+):(\d+):(\d+)\]',body,flags=re.M)
        if tss:
            h,m,s=map(int,tss[-1]); last=h*3600+m*60+s
            if dur-last>420:
                return "SUSPECT",chars,(f"abgeschnitten? letzte Marke {last//60}min, "
                                        f"Audio {int(dur//60)}min (Lücke {(dur-last)/60:.0f}min)")
    mins=max(dur/60.0,0.5)
    cpm=chars/mins
    if chars<200: return "FAIL",chars,f"quasi leer ({chars} chars)"
    if cpm<180: return "SUSPECT",chars,f"sehr wenig Text: {cpm:.0f} chars/min (erwartet ~600-1000)"
    return "OK",chars,f"{cpm:.0f} chars/min"

def ffprobe_dur(p):
    out=subprocess.run(["ffprobe","-v","error","-show_entries","format=duration","-of","default=nw=1:nk=1",p],
        capture_output=True,text=True).stdout.strip()
    return float(out) if out else 0.0

def hms(s): s=int(s); return f"{s//3600:02d}:{(s%3600)//60:02d}:{s%60:02d}"

def download(item, audio_path):
    os.makedirs(os.path.dirname(audio_path),exist_ok=True)
    if item["source"]=="panopto":
        url=f"https://tu-darmstadt.cloud.panopto.eu/Panopto/Pages/Viewer.aspx?id={item['ref']}"
        out_tmpl=audio_path[:-4]+".%(ext)s"
        r=subprocess.run(["yt-dlp","--cookies",CK,"-f","worst","-x","--audio-format","mp3",
            "--postprocessor-args","-ar 16000 -ac 1","--no-warnings","-o",out_tmpl,url],
            capture_output=True,text=True)
        return os.path.exists(audio_path), r.stderr[-300:]
    # direct mp4/mp3 (FB18 moodleload / FB01-Camtasia abgeleitetes mp4) -> curl -L (folgt CAS) -> ffmpeg 16k mono
    raw=audio_path[:-4]+".raw"
    rc=subprocess.run(["curl","-s","-L","-b",CK,"--max-time","900","-o",raw,item["ref"]],capture_output=True,text=True)
    if not (os.path.exists(raw) and os.path.getsize(raw)>10000):
        return False, f"curl-DL leer/fehlgeschlagen ({os.path.getsize(raw) if os.path.exists(raw) else 0}b)"
    rf=subprocess.run(["ffmpeg","-nostdin","-loglevel","error","-y","-i",raw,"-ar","16000","-ac","1",audio_path],
        capture_output=True,text=True)
    if os.path.exists(raw): os.remove(raw)
    return os.path.exists(audio_path), rf.stderr[-300:]

def write_frontmatter(out_path, item, dur):
    body=open(out_path,encoding="utf-8").read()
    fm=["---","type: transkript",f"modul: {item['modul']}",f"einheit: {item['slug']}"]
    if item["source"]=="panopto": fm+=[f"panopto_id: {item['ref']}"]
    else: fm+=[f"quelle_url: {item['ref']}"]
    if item.get("cmid"): fm+=[f"cmid: {item['cmid']}"]
    fm+=[f"dauer: {hms(dur)}","modell: gpt-4o-transcribe",f"sprache: {item['lang']}",
         f"transkribiert_am: {datetime.date.today().isoformat()}",
         f"quelle: \"{item['titel']}\"","---",""]
    open(out_path,"w",encoding="utf-8").write("\n".join(fm)+body)

def process(item):
    modul,slug=item["modul"],item["slug"]
    key=f"{modul}/{slug}"
    if have_transcript(modul,slug):
        return {"key":key,"status":"SKIP","note":"existiert","chars":0,"dur":0}
    audio=f"{MIRROR}/{modul}/aufzeichnungen/{slug}.mp3"
    if not (os.path.exists(audio) and os.path.getsize(audio)>10000):
        ok,err=download(item,audio)
        if not ok: return {"key":key,"status":"FAIL","note":f"Download: {err[:120]}","chars":0,"dur":0}
    dur=ffprobe_dur(audio)
    out=transcript_path(modul,slug)
    terms=f"{LT}/{modul}-terms.txt" if modul in TERMS_EXIST else ""
    cmd=["python3",TRANSCRIBE,audio,out,"--seg","300","--title",f"{slug} {item['titel']}"[:80],"--lang",item["lang"]]
    if terms: cmd+=["--prompt-file",terms]
    r=subprocess.run(cmd,capture_output=True,text=True,env=dict(os.environ))
    if not (os.path.exists(out) and os.path.getsize(out)>200):
        return {"key":key,"status":"FAIL","note":f"Transkription: {r.stderr[-120:]}","chars":0,"dur":dur}
    write_frontmatter(out,item,dur)
    status,chars,note=verify(out,dur)
    return {"key":key,"status":status,"note":note,"chars":chars,"dur":dur,"lang":item["lang"],"src":item["source"]}

def build_queue(only=None):
    man=json.load(open(f"{LT}/full_manifest.json"))
    guids=json.load(open(f"{LT}/guids.json")) if os.path.exists(f"{LT}/guids.json") else {}
    q=[]
    for modul,d in man.items():
        if only and modul not in only: continue
        lang=LANG.get(modul,"de"); used=set()
        for x in d.get("lti",[]):
            g=guids.get(x["cmid"],{}).get("guid")
            if not g or g=="NONE": continue
            q.append({"modul":modul,"slug":slugify_lti(x["titel"],used),"lang":lang,
                      "source":"panopto","ref":g,"cmid":x["cmid"],"titel":x["titel"]})
        seen_url=set()
        for m in d.get("media",[]):
            tgt=m["target"]
            # CAS-Login-Wrapper -> echtes Ziel aus service= dekodieren
            if "idp/profile/cas/login" in tgt and "service=" in tgt:
                tgt=urllib.parse.unquote(tgt.split("service=",1)[1])
            # Boilerplate-Hilfeseite raus
            if "Video-Tutorials/start.html" in tgt: continue
            # .html-Camtasia-Wrapper -> Geschwister-.mp4
            if tgt.lower().endswith(".html"): tgt=tgt[:-5]+".mp4"
            if not re.search(r'\.(mp4|m4v|webm|mov|mp3|m4a)(\?|$)',tgt,re.I): continue
            if tgt in seen_url: continue
            seen_url.add(tgt)
            q.append({"modul":modul,"slug":slugify_media(m["titel"],tgt,used),"lang":lang,
                      "source":"direct","ref":tgt,"cmid":m.get("cmid"),"titel":m["titel"]})
    return q

STATUS=f"{LT}/bulk_status.json"
def commit_vault(msg):
    try:
        subprocess.run(["git","-C",VAULT,"add","projekte/lernplan"],capture_output=True)
        r=subprocess.run(["git","-C",VAULT,"commit","-m",msg],capture_output=True,text=True)
        if "nothing to commit" not in (r.stdout+r.stderr):
            subprocess.run(["git","-C",VAULT,"push"],capture_output=True)
    except Exception as e: print("commit-err:",e,flush=True)

if __name__=="__main__":
    ap=argparse.ArgumentParser()
    ap.add_argument("--only",nargs="*"); ap.add_argument("--workers",type=int,default=5)
    ap.add_argument("--limit",type=int,default=0); ap.add_argument("--per-module",type=int,default=0)
    ap.add_argument("--dry",action="store_true")
    a=ap.parse_args()
    q=build_queue(a.only)
    todo=[it for it in q if not have_transcript(it["modul"],it["slug"])]
    if a.per_module:
        seen={}; sel=[]
        for it in todo:
            seen.setdefault(it["modul"],0)
            if seen[it["modul"]]<a.per_module: sel.append(it); seen[it["modul"]]+=1
        todo=sel
    if a.limit: todo=todo[:a.limit]
    print(f"Queue: {len(q)} Items, {len(todo)} offen.",flush=True)
    by={}
    for it in q: by.setdefault(it["modul"],[0,0]); by[it["modul"]][0]+=1
    for it in todo:
        if it["modul"] in by: by[it["modul"]][1]+=1
    for mod,(tot,off) in sorted(by.items()): print(f"  {mod:24s} {tot:3d} total, {off:3d} offen",flush=True)
    if a.dry:
        for it in todo: print(f"   - {it['modul']}/{it['slug']} [{it['source']}/{it['lang']}] {it['titel'][:45]}",flush=True)
        sys.exit(0)
    status=json.load(open(STATUS)) if os.path.exists(STATUS) else {}
    done=0; cnt={"OK":0,"SUSPECT":0,"FAIL":0,"SKIP":0}
    with cf.ThreadPoolExecutor(max_workers=a.workers) as ex:
        for res in ex.map(process,todo):
            done+=1; cnt[res["status"]]=cnt.get(res["status"],0)+1
            status[res["key"]]={k:res.get(k) for k in ("status","note","chars","dur","lang","src")}
            json.dump(status,open(STATUS,"w"),ensure_ascii=False,indent=1)
            mark={"OK":"✓","SUSPECT":"⚠","FAIL":"✗","SKIP":"·"}.get(res["status"],"?")
            print(f"[{done}/{len(todo)}] {mark} {res['key']} — {res['note']}",flush=True)
            if done%10==0:
                commit_vault(f"transkripte: bulk {done}/{len(todo)} (OK={cnt['OK']} SUSPECT={cnt['SUSPECT']} FAIL={cnt['FAIL']})")
                print(f"   … Zwischenstand: OK={cnt['OK']} SUSPECT={cnt['SUSPECT']} FAIL={cnt['FAIL']}",flush=True)
    commit_vault(f"transkripte: bulk fertig (OK={cnt['OK']} SUSPECT={cnt['SUSPECT']} FAIL={cnt['FAIL']})")
    print(f"FERTIG. OK={cnt['OK']} SUSPECT={cnt['SUSPECT']} FAIL={cnt['FAIL']} SKIP={cnt['SKIP']}",flush=True)
    print(f"Status-Datei: {STATUS}",flush=True)

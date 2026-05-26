#!/usr/bin/env python3
"""Transkribiert eine Audio-Datei chunk-weise mit gpt-4o-transcribe.
- Splittet in feste Segmente (Default 300 s) für Zeitmarken + 25-MB-Limit-Sicherheit.
- Verkettet Kontext (Fachbegriffe + letzte Sätze des Vor-Chunks) als prompt → bessere Begriffe + Grenzen.
- Schreibt timestamped Markdown.

Nutzung: transcribe.py <input.mp3> <output.md> [--seg 300] [--title "VO01"] [--prompt-file terms.txt]
Key: OPENAI_API_KEY_PRIVATE (privat) bzw. _WORK (EDP) — Kontext-abhängig, siehe credentials.md.
"""
import os, sys, subprocess, tempfile, json, argparse, urllib.request, urllib.error

def ffprobe_dur(p):
    out = subprocess.run(["ffprobe","-v","error","-show_entries","format=duration",
                          "-of","default=nw=1:nk=1",p], capture_output=True, text=True).stdout.strip()
    return float(out) if out else 0.0

def hms(s):
    s=int(s); return f"{s//3600:02d}:{(s%3600)//60:02d}:{s%60:02d}"

def transcribe_chunk(path, key, prompt):
    # multipart/form-data manuell (keine externen Deps)
    boundary="----jarvisASR"; nl="\r\n"
    fields={"model":"gpt-4o-transcribe","language":"de","response_format":"json","prompt":prompt}
    body=b""
    for k,v in fields.items():
        body+=f"--{boundary}{nl}Content-Disposition: form-data; name=\"{k}\"{nl}{nl}{v}{nl}".encode()
    with open(path,"rb") as f: audio=f.read()
    body+=f"--{boundary}{nl}Content-Disposition: form-data; name=\"file\"; filename=\"a.mp3\"{nl}Content-Type: audio/mpeg{nl}{nl}".encode()
    body+=audio+f"{nl}--{boundary}--{nl}".encode()
    req=urllib.request.Request("https://api.openai.com/v1/audio/transcriptions", data=body,
        headers={"Authorization":f"Bearer {key}","Content-Type":f"multipart/form-data; boundary={boundary}"})
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            return json.loads(r.read()).get("text","").strip()
    except urllib.error.HTTPError as e:
        return f"[FEHLER {e.code}: {e.read().decode()[:200]}]"

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("input"); ap.add_argument("output")
    ap.add_argument("--seg",type=int,default=300)
    ap.add_argument("--title",default="")
    ap.add_argument("--prompt-file",default="")
    a=ap.parse_args()
    key=os.environ.get("OPENAI_API_KEY_PRIVATE") or os.environ.get("OPENAI_API_KEY_WORK")
    if not key: sys.exit("Kein OPENAI_API_KEY_PRIVATE/_WORK im Environment.")
    terms=open(a.prompt_file).read().strip() if a.prompt_file and os.path.exists(a.prompt_file) else ""
    os.makedirs(os.path.dirname(os.path.abspath(a.output)),exist_ok=True)
    with tempfile.TemporaryDirectory() as td, open(a.output,"w") as fout:
        subprocess.run(["ffmpeg","-nostdin","-loglevel","error","-y","-i",a.input,
            "-f","segment","-segment_time",str(a.seg),"-c","copy",f"{td}/c_%03d.mp3"],check=True)
        chunks=sorted(f for f in os.listdir(td) if f.startswith("c_"))
        fout.write(f"# Transkript — {a.title or a.input}\n\n> Auto-Transkription via gpt-4o-transcribe "
                   f"(Chunk={a.seg}s). Maschinell — Fachbegriffe ggf. prüfen.\n")
        fout.flush()
        offset=0.0; prev=""
        for i,c in enumerate(chunks):
            cp=os.path.join(td,c)
            prompt=(terms+" "+prev[-300:]).strip()
            text=transcribe_chunk(cp,key,prompt)
            fout.write(f"\n## [{hms(offset)}]\n\n{text}\n"); fout.flush()   # inkrementell → nie Datenverlust
            print(f"  chunk {i+1}/{len(chunks)} @ {hms(offset)} — {len(text)} chars",file=sys.stderr)
            offset+=ffprobe_dur(cp); prev=text
    print(f"→ {a.output} ({len(chunks)} chunks, {hms(offset)})",file=sys.stderr)

if __name__=="__main__": main()

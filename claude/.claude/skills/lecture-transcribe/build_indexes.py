#!/usr/bin/env python3
"""Nachbereitung: pro Modul transkripte/INDEX.md (Tabelle slug · dauer · sprache · status · chars)
aus den Frontmattern + bulk_status.json, plus Goldquellen-Hinweis in der strategie.md (idempotent)."""
import os, re, json, glob
LT="/Users/timrudorf/Documents/uni/lecture-tools"
VAULT="/Users/timrudorf/Documents/jarvis-wiki"
status=json.load(open(f"{LT}/bulk_status.json")) if os.path.exists(f"{LT}/bulk_status.json") else {}

def fm(path):
    t=open(path,encoding="utf-8",errors="replace").read()
    m=re.match(r'---\n(.*?)\n---',t,re.S)
    d={}
    if m:
        for line in m.group(1).splitlines():
            if ":" in line: k,_,v=line.partition(":"); d[k.strip()]=v.strip().strip('"')
    return d

MARK={"OK":"✅","SUSPECT":"⚠️","FAIL":"❌"}
for tdir in sorted(glob.glob(f"{VAULT}/projekte/lernplan/*/transkripte")):
    modul=tdir.split("/")[-2]
    files=sorted(f for f in glob.glob(f"{tdir}/*.md") if os.path.basename(f)!="INDEX.md")
    if not files: continue
    rows=[]
    for f in files:
        slug=os.path.basename(f)[:-3]; d=fm(f)
        st=status.get(f"{modul}/{slug}",{}).get("status","?")
        rows.append((slug,d.get("dauer","?"),d.get("sprache","?"),MARK.get(st,st),d.get("quelle","")[:50]))
    lines=[f"# Transkripte — {modul}","",f"{len(files)} Aufzeichnungen, auto-transkribiert (gpt-4o-transcribe). "
           "Primärquelle bei der LE-Erstellung — Anker-Format `Transkript <slug> @ [MM:SS]`.","",
           "| Einheit | Dauer | Spr | Status | Quelle |","|---|---|---|:--:|---|"]
    for slug,dur,lang,mk,q in rows: lines.append(f"| [[{slug}]] | {dur} | {lang} | {mk} | {q} |")
    open(f"{tdir}/INDEX.md","w",encoding="utf-8").write("\n".join(lines)+"\n")
    print(f"{modul}: INDEX.md ({len(files)} Einträge)")
    # Goldquellen-Hinweis in strategie.md (idempotent)
    strat=f"{VAULT}/projekte/lernplan/{modul}/strategie.md"
    if os.path.exists(strat):
        s=open(strat,encoding="utf-8").read()
        if "transkripte/INDEX" not in s and "transkripte/" not in s:
            note=f"\n\n> [!note] Vorlesungs-Transkripte (Goldquelle)\n> Volltext-Transkripte aller verlinkten Aufzeichnungen unter [[{modul}/transkripte/INDEX|transkripte/]] — Primärquelle bei LE-Erstellung, v.a. für nur-verbal beantwortete Kontrollfragen.\n"
            open(strat,"a",encoding="utf-8").write(note); print(f"   + Goldquellen-Hinweis in strategie.md")
print("fertig.")

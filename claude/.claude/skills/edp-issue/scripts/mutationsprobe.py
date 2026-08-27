#!/usr/bin/env python3
"""Mutationsprobe gegen die EDP-Dev-VM.

Macht die eigenen Schutzmaßnahmen gezielt kaputt und belegt, dass die Suite das
merkt. Fährt die Reihe seriell (nicht per workflow_dispatch-Schwarm) und prüft je
Fall vier Dinge, ohne die eine Probe still lügt:

  1. hat die Mutation den Baum wirklich verändert?
  2. ist der Push serverseitig angekommen?  (sonst misst der Fall den Vorgänger)
  3. stimmt die Zahl der gefundenen Tests?  (sonst lief die Prüfung gar nicht mit)
  4. sind genau die ERWARTETEN Testnamen rot?  (nicht bloss irgendwelche)

Benutzung: KONFIG und FAELLE unten anpassen, dann als Hintergrundlauf starten.
Ergebnisse landen in <OUT>/ergebnis.txt, die Rohausgabe je Fall daneben.

Pflichtbestandteile jeder Fallliste — ohne sie ist die Reihe nichts wert:
  * eine Baseline OHNE Mutation (erwartet 0 rot)
  * mindestens eine Gegenrichtung (harmlose Änderung, erwartet 0 rot)
  * eine Verdrahtungsprobe (Testunit aus dem .dpr) mit kleinerer Testanzahl

Der Zweigname muss je Reihe NEU sein. Ein wiederverwendeter Name liegt auf origin
noch auf dem alten Stand; der Push wird still abgewiesen und jeder Fall misst den
Vorgänger. Nach der Reihe lokal und auf origin löschen.
"""

import io
import os
import re
import shutil
import subprocess

# ── KONFIG ──────────────────────────────────────────────────────────────────
REPO  = 'schn_ivena'
ROOT  = os.path.expanduser('~/dev/EDP/.worktrees/<vorgang>-mut')   # Eltern von <repo>
WT    = os.path.join(ROOT, REPO)
BR    = 'tmp/<vorgang>-mut1'          # je Reihe NEU
BASIS = '<sha>'                       # Stand, gegen den mutiert wird
OUT   = os.path.expanduser('~/.cache/mutationsprobe')

# Dateien, die mutiert werden (werden vor der Reihe gesichert)
DATEIEN = [
    'src/…',
]

# (id, beschreibung, [(datei, alt, neu), …], erwartete_testzahl, erwartete_rote_kurznamen)
FAELLE = [
    ('00-baseline', 'unveraendert', [], 0, []),
]
# ────────────────────────────────────────────────────────────────────────────


def sh(cmd, cwd=WT):
    return subprocess.run(cmd, cwd=cwd, shell=True, capture_output=True, text=True)


def sichern():
    b = os.path.join(OUT, 'backup')
    os.makedirs(b, exist_ok=True)
    for f in DATEIEN:
        ziel = os.path.join(b, f.replace('/', '__'))
        shutil.copyfile(os.path.join(WT, f), ziel)
        os.chmod(ziel, 0o644)          # 755 machte jede Ruecksicherung zu einer Aenderung


def herstellen():
    b = os.path.join(OUT, 'backup')
    for f in DATEIEN:
        # copyfile, nicht copy2: copy2 traegt den Modus mit und Git verfolgt das x-Bit
        shutil.copyfile(os.path.join(b, f.replace('/', '__')), os.path.join(WT, f))


def parse(txt):
    """Liefert (gefundene_tests, rot, rote_kurznamen)."""
    txt = txt.replace('\r', '')        # die VM liefert CRLF; ohne das findet kein $-Anker
    def zahl(label):
        m = re.search(rf'^{label}\s*:\s*(\d+)', txt, re.M)
        return int(m.group(1)) if m else None
    gefunden = zahl('Tests Found')
    rot = (zahl('Tests Failed') or 0) + (zahl('Tests Errored') or 0)   # DUnitX zaehlt getrennt
    namen = []
    i = txt.find('Failing Tests')
    if i >= 0:
        for z in txt[i:].split('\n')[1:]:
            t = z.strip()
            if t.count('.') >= 2 and ':' not in t and ' ' not in t:
                namen.append(t.split('.')[-1])
    return gefunden, rot, sorted(set(namen))


def main():
    os.makedirs(OUT, exist_ok=True)
    erg = open(os.path.join(OUT, 'ergebnis.txt'), 'w', buffering=1)
    sh(f'git reset --hard {BASIS}')
    sichern()
    sh(f'git push -q origin {BR}')

    for fid, beschr, muts, soll_anz, soll_rot in FAELLE:
        herstellen()
        kaputt = False
        for datei, alt, neu in muts:
            p = os.path.join(WT, datei)
            s = io.open(p, encoding='utf-8-sig', newline='').read()
            if s.count(alt) != 1:
                erg.write(f'{fid} | UNGUELTIG: Anker {s.count(alt)}x in {datei}\n')
                kaputt = True
                break
            io.open(p, 'w', encoding='utf-8-sig', newline='').write(s.replace(alt, neu, 1))
        if kaputt:
            continue

        # porcelain, nicht `git diff --quiet`: letzteres meldet auch stat-dirty
        dreckig = sh('git status --porcelain').stdout.strip()
        if fid.startswith('00') and dreckig:
            erg.write(f'{fid} | UNGUELTIG: Baseline nicht sauber -> {dreckig[:120]}\n')
            continue
        if not fid.startswith('00') and not dreckig:
            erg.write(f'{fid} | UNGUELTIG: Mutation hat den Baum nicht veraendert\n')
            continue

        if dreckig:
            sh('git add -A')
            sh(f'git commit -q -m "mut {fid}"')
        sh(f'git push -q origin {BR}')

        lokal = sh('git rev-parse HEAD').stdout.strip()
        fern = sh(f'git ls-remote origin refs/heads/{BR}').stdout.split('\t')[0].strip()
        if lokal != fern:
            erg.write(f'{fid} | UNGUELTIG: Push nicht angekommen ({lokal[:7]} != {fern[:7]})\n')
            continue

        r = sh(f'edp-ctrl dev test {REPO} --project-root {ROOT}', cwd=ROOT)
        roh = r.stdout + r.stderr
        io.open(os.path.join(OUT, f'mut-{fid}.txt'), 'w').write(roh)

        anz, rot, namen = parse(roh)
        if anz is None:
            erg.write(f'{fid} | UNGUELTIG: kein "Tests Found" - Bau gescheitert? | {beschr}\n')
            continue
        ok = (anz == soll_anz) and (namen == sorted(set(soll_rot)))
        erg.write(f'{fid} | {"OK" if ok else "ABWEICHUNG"} | '
                  f'gefunden={anz}(soll {soll_anz}) rot={rot} | '
                  f'namen={",".join(namen) or "-"} | soll={",".join(sorted(set(soll_rot))) or "-"} | {beschr}\n')

    herstellen()
    sh('git add -A')
    sh('git commit -q -m "mut zurueckgebaut"')
    diff = sh(f'git diff --stat {BASIS} -- ' + ' '.join(DATEIEN)).stdout.strip()
    erg.write(f'\nRueckbau-Gegenprobe gegen {BASIS}: {diff or "keine Abweichung"}\n')
    erg.write(f'Faelle: {len(FAELLE)}\n')   # gegen die Zahl der Ergebniszeilen halten
    erg.close()


if __name__ == '__main__':
    main()

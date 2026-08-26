---
paths:
  - "**/*.pas"
  - "**/*.dpr"
  - "**/*.dpk"
  - "**/*.inc"
  - "**/*.dfm"
---

# Delphi-Dateien

## Encoding: Windows-1252, nicht UTF-8

Diese Dateien sind **Windows-1252**. Read/Edit/Write arbeiten UTF-8 — eine
Win-1252-`.pas` damit zu editieren zerschießt Umlaute zu U+FFFD, und die
CI-Stufe `delphi-validate-encoding` fängt das.

Sichere Wege: auf der VM editieren · byte-genauer `git checkout`-Restore ·
oder nach dem Edit `iconv -f UTF-8 -t WINDOWS-1252 <datei> -o <datei>` und
anschließend auf U+FFFD prüfen.

Volltext: [[tim/feedback/datei-encoding]]

## Tests wachsen mit

Jede Delphi-Änderung ergänzt oder passt DUnitX-Tests an, und **vor jedem
Commit läuft die gesamte Suite** — nur grün wird committet. So wächst die
Abdeckung inkrementell statt als einmaliger Kraftakt.

Volltext: [[tim/feedback/delphi-tests-immer]]

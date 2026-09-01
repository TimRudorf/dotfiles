---
paths:
  - "**/*.pas"
  - "**/*.dpr"
  - "**/*.dpk"
  - "**/*.inc"
  - "**/*.dfm"
---

# Delphi-Dateien

## Encoding: messen, nicht annehmen

`.pas` & Co. sind **meistens Windows-1252** — aber nicht überall. `edp/schn_ivena`
führt seine Quellen als **UTF-8 mit BOM** und lässt das von einer CI-Stufe
erzwingen. Wer dort nach Win-1252 konvertiert, kodiert doppelt; wer umgekehrt in
einem Win-1252-Repo direkt mit Edit schreibt, zerschießt die Umlaute zu U+FFFD.

Die Regel ist deshalb kein Wert, sondern ein Handgriff: **vorher erheben,
nachher gegenlesen.** Was dabei herauskommt, entscheidet den Weg — nicht die
Erwartung.

```bash
file -b <datei>                      # "ISO-8859" / "Non-ISO extended-ASCII"  vs.  "UTF-8 (with BOM)"
git log --oneline -- <datei> | head  # eine Encoding-Umstellung steht als eigener Commit drin
```

| Befund | Weg |
|---|---|
| Windows-1252 | auf der VM editieren · byte-genauer `git checkout`-Restore · oder nach dem Edit `iconv -f UTF-8 -t WINDOWS-1252 <datei> -o <datei>` |
| UTF-8 mit BOM | direkt mit Edit/Write, BOM erhalten, **kein** `iconv` |

## Gegenlesen ist der eigentliche Auftrag

Nach jedem Edit, in beiden Fällen:

```bash
file -b <datei>                       # muss dieselbe Ausgabe liefern wie vorher
/usr/bin/grep -c $'\xef\xbf\xbd' <datei>   # muss 0 sein
```

`/usr/bin/grep`, weil `grep` hier ein Wrapper ist und stumm mit Exit 0 scheitern
kann.

Zeilenenden gehören mitgeprüft: IDE-Dateien (`.dproj`, `.dfm`, `.groupproj`)
tragen CRLF, und ein Werkzeug im Textmodus dreht die ganze Datei still auf LF —
der Inhalt stimmt, der Diff ist Unsinn. Kontrolle über den Umfang des Diffs:

```bash
git diff --stat -- <pfad>   # zwei Zeilen Edit = zwei Zeilen Diff
```

Die CI-Encoding-Stufe fängt beide Fehler — aber erst nach dem Push, und dann ist
der kaputte Stand schon Historie.

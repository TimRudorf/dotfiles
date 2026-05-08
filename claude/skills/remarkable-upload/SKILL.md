---
name: remarkable-upload
description: "User invokes /remarkable-upload to push files (PDF, EPUB) to the reMarkable Cloud or list/create folders there. Wraps the `rmapi` CLI (ddvk/rmapi) for full sync v3 access — supports nested folder creation, listing, recursive sync. Sub-Commands: `put <local-file> <remote-dir>` (auto-mkdir parents), `ls [path]`, `mkdir <path>` (idempotent), `sync <local-dir> <remote-dir>` (mirror local PDFs into a folder). Trigger keywords: remarkable, hochladen, upload, /remarkable-upload, rm-upload, tablet, sync nach remarkable."
disable-model-invocation: true
argument-hint: <put|ls|mkdir|sync> [args]
---

# reMarkable Upload — rmapi-basierter Wrapper

Wrappt `rmapi` (Go-CLI von ddvk) für PDF/EPUB-Uploads, Folder-Listing und mkdir-Operationen auf der reMarkable Cloud. Authentifizierung läuft einmal pro Host via 8-stelligem Pairing-Code (Desktop-Connect).

## Voraussetzungen

- Tools: `~/.local/bin/rmapi` (Mac) bzw. `/usr/local/bin/rmapi` (Container) — Binary muss installiert sein
- Auth-Setup: `~/.config/rmapi/` muss existieren und der Token muss valide sein

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag → Setup-Anleitung anzeigen (siehe Schritt 0).

## Schritt 0 — Auth-Setup (one-time pro Host)

Wenn `rmapi ls /` mit "Enter one-time code" antwortet:

1. User auf https://my.remarkable.com/device/desktop/connect schicken
2. 8-stelligen Code abfragen
3. Code an `rmapi` weiterreichen — z.B. via `echo "<code>" | rmapi ls /`
4. rmapi tauscht Code gegen Device-Token, speichert in `~/.config/rmapi/rmapi.conf`

Auf jedem Host (Mac, Container) ist ein eigenes Pairing nötig. Wer Tokens portieren will, kopiert die `rmapi.conf` (devicetoken-Zeile) zwischen Hosts.

## Schritt 1 — Argumente parsen

Erstes Argument ist das Sub-Command (`put`, `ls`, `mkdir`, `sync`). Bei unbekanntem oder fehlendem Sub-Command: knappe Usage anzeigen und stoppen.

## Sub-Command: `put <local-file> <remote-dir>`

Lädt eine lokale PDF/EPUB-Datei in einen reMarkable-Folder hoch. Folder wird **automatisch angelegt** wenn er nicht existiert (mkdir-p auf alle Parents).

```bash
bash scripts/rm.sh put <local-file> <remote-dir>
```

Beispiel:
```bash
bash scripts/rm.sh put ~/Documents/uni/sensortechnik-fb18-archive/STV01-min.pdf /Studium/Sensortechnik/
```

Idempotent: Existing files mit gleichem Namen werden überschrieben (rmapi default).

Output bei Erfolg:
```
✅ Uploaded: STV01-min.pdf → /Studium/Sensortechnik/STV01-min
```

## Sub-Command: `ls [path]`

Listet Inhalt eines Folders. Default-Path ist `/`.

```bash
bash scripts/rm.sh ls [path]
```

Output (`[d]` für Folder, `[f]` für File):
```
[d]	Sensortechnik
[d]	SDRT3
[f]	STV01-min
```

## Sub-Command: `mkdir <path>`

Legt einen Folder-Pfad an, **idempotent** (no-op wenn schon da). Auto-mkdir-p für nested paths.

```bash
bash scripts/rm.sh mkdir <path>
```

Beispiel:
```bash
bash scripts/rm.sh mkdir /Studium/Sensortechnik
```

Output: `✅ Folder ready: /Studium/Sensortechnik` (ob neu oder existing).

## Sub-Command: `sync <local-dir> <remote-dir>`

Mirror-Upload: alle PDFs/EPUBs aus dem lokalen Verzeichnis in den reMarkable-Folder. Nicht-rekursiv (nur top-level der lokalen Dir).

```bash
bash scripts/rm.sh sync <local-dir> <remote-dir>
```

Output zählt Erfolge/Fehler.

## Modul-Slug → reMarkable-Folder Mapping

Andere Skills (z.B. `lerneinheit`) nutzen dieses Mapping für die automatische Ablage von Lernunterlagen. Source-of-Truth: `scripts/rm.sh` Funktion `slug_to_folder`.

| Modul-Slug | reMarkable-Folder |
|---|---|
| `sensortechnik` | `/Studium/Sensortechnik` |
| `sdrt3` | `/Studium/SDRT3` |
| `thermo` | `/Studium/Thermo` |
| `mldl-auto` | `/Studium/ML-DL` |
| `praktikum-rt2` | `/Studium/P-RT2` |
| `mpc-ml` | `/Studium/MPC-ML` |
| `rvcps` | `/Studium/CDCPS` |
| `dimm` | `/Studium/DIMM` |
| `ppm-seminar` | `/Studium/PPM-Seminar` |
| `entrepreneurial` | `/Studium/Entrepreneurial` |
| `modern-firm` | `/Studium/Modern-Firm` |
| `international-economics` | `/Studium/IntEco` |

## Stolperfallen

- **`rmapi rm -r` ist buggy** (v0.0.33): rekursive Folder-Deletes ziehen Children in die Eltern-Ebene statt sie mitzulöschen. Workaround: leaves-first löschen (siehe `scripts/rm_clean.sh` falls eines Tages gebraucht).
- **Auth-Token-Typ**: rmapi will einen **Desktop**-Token (von `/device/desktop/connect`), nicht einen WebApp-/Browser-Token. Der env-var `RM_DEVICE_TOKEN` aus früheren curl-basierten Workflows ist nicht kompatibel.
- **Pro Host eigene Auth**: Tokens sind hostspezifisch (Mac vs. Container brauchen je eigenen Pairing-Schritt) — siehe Schritt 0.
- **Filename-Truncation**: rmapi entfernt die `.pdf`-Extension beim Display (UI zeigt nur den Basename). Funktional ändert sich nichts.

Abschließend `skill-optimize` mit `remarkable-upload` aufrufen.

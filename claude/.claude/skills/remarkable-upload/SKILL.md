---
name: remarkable-upload
description: "Uploads PDFs and EPUBs to a reMarkable tablet via Simple Upload API (curl-basiert, kein rmapi-js). Use when the user asks to upload files to reMarkable, send documents to reMarkable, or when another skill needs to push files to the reMarkable cloud. Trigger keywords: remarkable, upload, hochladen, tablet."
argument-hint: "[datei-pfad] [ziel-ordner]"
---

# reMarkable Upload

Lädt PDFs und EPUBs auf ein reMarkable Tablet hoch — via Simple Upload API (2 HTTP-Requests, kein rmapi-js).

## Voraussetzungen
- Env: `RM_DEVICE_TOKEN`
- Tools: `curl`

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Schritt 1: Argumente bestimmen

Aus `$ARGUMENTS` extrahieren:
- **Dateipfad(e)**: Einzelne Datei oder Verzeichnis (dann alle PDFs/EPUBs darin)
- **Zielordner** (optional): Name eines Ordners auf dem reMarkable. Default: Root-Ebene.

Falls Argumente unvollständig (kein Dateipfad): Nachfragen. Kommunikationsweg gemäß `CLAUDE_COMM_CHANNEL` wählen (siehe `.shared/communication.md`).

## Schritt 2: Dateien validieren

Prüfe ob die angegebene(n) Datei(en) existieren und PDF oder EPUB sind.

Bei Verzeichnis: Alle `.pdf` und `.epub` Dateien darin sammeln.

Falls keine gültigen Dateien gefunden: Abbrechen mit Hinweis.

## Schritt 3: Folder-ID bestimmen

Bekannte Ordner-IDs (in `/etc/environment`):
- `RM_DIGEST_FOLDER_ID` → "Daily News Digest"

Wenn der Zielordner bekannt ist, direkt die ID verwenden.

Wenn der Zielordner unbekannt ist, ID aus dem Cache lesen:
```bash
cat ~/.cache/remarkable-folders.json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('ORDNERNAME',{}).get('id',''))"
```

Falls nicht im Cache: Upload ohne `parent` (landet im Root), User informieren.

## Schritt 4: Upload ausführen

Das Upload-Script liegt unter `scripts/rm_upload.sh` relativ zu dieser SKILL.md.

Aufruf pro Datei:

```bash
bash <skill-dir>/scripts/rm_upload.sh "<dateipfad>" ["<folder-id>"]
```

Das Script:
1. Holt einen User Token via `RM_DEVICE_TOKEN`
2. Setzt `rm-meta` Header mit Dateiname und optionaler Parent-ID
3. Sendet die Datei an `internal.cloud.remarkable.com/doc/v2/files`
4. Gibt JSON auf stdout aus

Erfolg:
```json
{"success": true, "docID": "uuid", "fileName": "Dokument.pdf"}
```

Fehler:
```json
{"success": false, "error": "Beschreibung"}
```

## Schritt 5: Ergebnis melden

Bei Erfolg: Dateiname und Zielordner bestätigen.
Bei Fehler: Fehlermeldung anzeigen. Häufige Fehler:
- `401/Unauthorized`: Device Token abgelaufen → neuen Token unter https://my.remarkable.com/device/desktop/connect generieren und per `store-credential` speichern
- HTTP 4xx/5xx: reMarkable Cloud Problem → Retry empfehlen

Abschließend `skill-optimize` mit `remarkable-upload` aufrufen.

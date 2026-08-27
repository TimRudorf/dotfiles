#!/usr/bin/env python3
"""Native Anki Image-Occlusion-Karten headless via AnkiConnect bauen.

Referenz/Vorlage — verifiziert 2026-06-02 am VO02-Lauf (Sensortechnik).
Doku: Studium-Vault, Methodik/anki-konzept.md → "Image-Occlusion-Karten bauen — nativ & headless".

Kein IO-Enhanced-Addon nötig. Nutzt den NATIVEN Notetype "Image Occlusion".
Voraussetzungen am Mac: AnkiConnect (Anki offen), pdftoppm (poppler), Pillow.

Pipeline pro IO-Karte:
  1. Folie rendern:  pdftoppm -png -f S -l S -r 150 input.pdf prefix   (-> prefix-SS.png)
  2. Bild ansehen / Region croppen+zoomen, Maskenkoordinaten (0..1) schätzen.
  3. SELF-CHECK: overlay_check() -> PNG ansehen, sitzen die Masken?  (Pflicht!)
  4. build_io_notes() -> addNotes, pre+post Sync, Read-back.

Koordinaten sind normalisiert 0..1 (left, top, width, height) relativ zur Bildgröße.
Jede Maske = eigene Cloze-Gruppe cN = eine Occlusion-Karte. Gleiche cN = zusammen aufgedeckt.
"""
import json, urllib.request, base64

ANKI = "http://localhost:8765"

def call(action, **p):
    r = urllib.request.urlopen(ANKI,
        json.dumps({"action": action, "version": 6, "params": p}).encode(), timeout=60)
    res = json.load(r)
    if res.get("error"):
        raise RuntimeError(f"{action}: {res['error']}")
    return res["result"]

def occlusion_field(masks):
    """masks: list of (left, top, width, height) in 0..1 -> Occlusion-Feldtext."""
    return "\n".join(
        f"{{{{c{i}::image-occlusion:rect:left={l:.4f}:top={t:.4f}:width={w:.4f}:height={h:.4f}}}}}"
        for i, (l, t, w, h) in enumerate(masks, 1))

def overlay_check(src_png, masks, out_png):
    """SELF-CHECK: zeichnet die Masken halbtransparent aufs Original -> ansehen vor dem Bauen."""
    from PIL import Image, ImageDraw
    im = Image.open(src_png).convert("RGB"); W, H = im.size
    d = ImageDraw.Draw(im, "RGBA")
    for (l, t, w, h) in masks:
        d.rectangle([l*W, t*H, (l+w)*W, (t+h)*H],
                    fill=(255, 235, 162, 150), outline=(33, 33, 33, 255), width=3)
    im.save(out_png)
    return out_png

def store_image(local_path, media_name):
    with open(local_path, "rb") as f:
        return call("storeMediaFile", filename=media_name, data=base64.b64encode(f.read()).decode())

def build_io_notes(deck, tags, items, sync=True):
    """items: list of dict(local_png, media_name, masks, header, back_extra).
    Legt pro item eine Image-Occlusion-Note an. Gibt note-ids zurück."""
    if sync:
        call("sync")  # pre-sync (Sync-Race vermeiden)
    notes = []
    for it in items:
        img = store_image(it["local_png"], it["media_name"])
        notes.append({
            "deckName": deck, "modelName": "Image Occlusion",
            "fields": {"Occlusion": occlusion_field(it["masks"]),
                       "Image": f'<img src="{img}">',
                       "Header": it.get("header", ""),
                       "Back Extra": it.get("back_extra", ""), "Comments": ""},
            "tags": tags, "options": {"allowDuplicate": False}})
    ids = call("addNotes", notes=notes)
    for nid in [i for i in ids if i]:
        n = call("findCards", query=f"nid:{nid}")
        print(f"  note {nid}: {len(n)} Occlusion-Karten")
    if sync:
        call("sync")  # post-sync
    # Deck-Config / new/day-Limits werden NICHT automatisch angefasst — Tim pflegt die
    # Presets selbst von Hand in Anki (Auto-Normalizer entfernt 2026-07-07).
    return ids


# ---- Beispiel-Aufruf (VO02; zum Nachbauen Werte anpassen) --------------------
if __name__ == "__main__":
    DECK = "Uni::Sensortechnik"   # flach pro Modul, keine Subdecks (Schema 2026-06-29); VO via source-Tag
    TAGS = ["phase::1", "source::sensortechnik::vo02-statisches-uebertragungsverhalten"]
    # Folien vorher rendern, z.B.:
    #   pdftoppm -png -f 18 -l 18 -r 150 STV02-mit-Notizen.pdf /tmp/s   ->  /tmp/s-18.png
    items = [{
        "local_png": "/tmp/vo02_slides/s18-18.png",
        "media_name": "vo02-io-folie18-differenzmethode.png",
        "masks": [(0.6850, 0.2700, 0.1550, 0.0850),   # S(Δu)
                  (0.6850, 0.4600, 0.1550, 0.0850),   # S(−Δu)
                  (0.6000, 0.4500, 0.0600, 0.0850),   # −1-Block
                  (0.8520, 0.3550, 0.0550, 0.0700)],  # Subtraktionsknoten
        "header": "VO02 KF12 — Differenzmethode Blockschaltbild ⚑ (STV02 Folie 18)",
        "back_extra": "Δu=u−u0 → zwei Pfade S(Δu)/S(−Δu) (über −1), subtrahiert (y1−y2).",
    }]
    # 1) Self-Check vor dem Bauen:
    # overlay_check(items[0]["local_png"], items[0]["masks"], "/tmp/chk.png")  # -> ansehen!
    # 2) Bauen:
    print(build_io_notes(DECK, TAGS, items))

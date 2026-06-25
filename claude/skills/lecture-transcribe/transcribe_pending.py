#!/usr/bin/env python3
"""Queue-Drainer: transkribiert alle in den Vault-`_pending.json`-Queues offenen
Aufzeichnungen (befüllt vom Container via moodle_sync.py) — der Mac-Gegenpart zur
Container-Detection. Bug-2-Fix der Transkriptions-Pipeline (siehe
projekte/lernplan/vorlesungs-transkription/pipeline-bugfix-pickup.md).

Flow (von /transcribe orchestriert, interaktiv am Mac):
  1. Alle <modul>/transkripte/_pending.json einsammeln.
  2. Cookie-Vorabcheck (Panopto + ggf. CAS) — bei Ablauf abbrechen mit klarer Ansage,
     damit Tim sich headed neu einloggt (Re-Auth NUR am Mac, siehe SKILL.md Schritt 1).
  3. Pro offener Aufzeichnung: Quelle auflösen (LTI→Panopto-GUID headless; moodleload/
     Camtasia→Direkt-MP4; ws_file→WS-fileurl) → Download → 16 kHz mono mp3 → transcribe.py
     → Frontmatter (cmid + quelle_url für moodle_sync-Dedup) → Verify.
  4. Erfolg (OK/SUSPECT) → Eintrag aus _pending.json entfernen (Queue konvergiert).
     FAIL → Eintrag bleibt pending (idempotenter Retry beim nächsten Lauf).

Die schwere Arbeit (Download/ASR/Frontmatter/Verify) erbt es 1:1 aus transcribe_bulk.py
— hier kommt nur die Queue-Anbindung + Quellauflösung dazu, kein zweiter ASR-Pfad.

    python3 transcribe_pending.py --dry              # Queue zeigen, nichts tun
    python3 transcribe_pending.py                     # alle offenen abarbeiten
    python3 transcribe_pending.py --module modern-firm international-economics
    python3 transcribe_pending.py --limit 3
"""
import argparse
import json
import os
import re
import subprocess
import sys
import urllib.parse
from pathlib import Path

import transcribe_bulk as tb  # bewährte Helfer: download/verify/ffprobe_dur/hms/write_frontmatter/slugify/commit

VAULT_LERNPLAN = Path(tb.VAULT) / "projekte" / "lernplan"
# Stabile Panopto-Session zum Cookie-Gültigkeitstest (Sensortechnik VO00, reference.md §Auth-Test-GUID).
PANOPTO_TEST_GUID = "64311577-06c3-458f-a6e2-af3801217dfb"
# Token-Datei für WS-fileurl-Downloads (ws_file-Aufzeichnungen) — wie moodle_sync.
TOKEN_FILE = Path(os.path.expanduser("~/.config/moodle-dl/token.tim.json"))
MOODLELOAD_HOST = "moodleload.hrz.tu-darmstadt.de"
_GUID_RE = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", re.I)
_MEDIA_URL_RE = re.compile(r"\.(mp4|m4v|webm|mov|mp3|m4a)(?:\?|#|$)", re.I)


def derive_camtasia_mp4(url: str) -> str:
    """Camtasia-`.html`-Wrapper → Geschwister-`.mp4` (spiegelt moodle_sync.derive_camtasia_mp4)."""
    base = url.split("?", 1)[0].split("#", 1)[0]
    return re.sub(r"\.html?$", ".mp4", base, flags=re.I)


def classify_resolved_url(url: str):
    """Final-URL nach Redirect klassifizieren → ('panopto', guid) | ('direct', mp4) | (None, None)."""
    if not url:
        return None, None
    m = re.search(r"(?:Embed|Viewer)\.aspx\?id=([0-9a-f-]{36})", url, re.I)
    if m:
        return "panopto", m.group(1)
    if MOODLELOAD_HOST in url:
        low = url.split("?", 1)[0].lower()
        if low.endswith((".html", ".htm")):
            return "direct", derive_camtasia_mp4(url)
        if _MEDIA_URL_RE.search(url):
            return "direct", url
    return None, None


# ---------------------------------------------------------------------------
# Queue I/O
# ---------------------------------------------------------------------------

def load_queues(only_modules):
    """Liefert [(modul_slug, pending_path, [entries])] für alle (oder gefilterte) Module."""
    out = []
    for pend in sorted(VAULT_LERNPLAN.glob("*/transkripte/_pending.json")):
        modul = pend.parent.parent.name
        if only_modules and modul not in only_modules:
            continue
        try:
            entries = json.loads(pend.read_text()).get("pending", [])
        except Exception as e:  # noqa: BLE001
            print(f"⚠️  {modul}: _pending.json unlesbar ({e}) — übersprungen", flush=True)
            continue
        if entries:
            out.append((modul, pend, entries))
    return out


def remove_from_queue(pend_path: Path, identities_done: set):
    """Erfolgreich transkribierte Einträge aus der Queue entfernen (Identität = cmid/url)."""
    data = json.loads(pend_path.read_text())
    kept = [e for e in data.get("pending", []) if _identity(e) not in identities_done]
    pend_path.write_text(json.dumps({"pending": kept}, indent=2, ensure_ascii=False))


def _identity(entry: dict) -> str:
    """Spiegelt moodle_sync.recording_identity: LTI→cmid, sonst URL."""
    if entry.get("source") == "lti" or entry.get("modname") == "lti":
        return f"cmid:{entry.get('cmid')}"
    return entry.get("url") or f"cmid:{entry.get('cmid')}"


# ---------------------------------------------------------------------------
# Quellauflösung: pending-Eintrag → transcribe_bulk-Item
# ---------------------------------------------------------------------------

def extract_url(pw_output: str) -> str:
    """Erste http(s)-URL aus playwright-cli-Output ziehen.

    `playwright-cli eval` wrappt den Rückgabewert als `### Result\\n"<url>"\\n### Ran …`.
    Den Blob direkt zu klassifizieren scheitert (das schließende `"` hängt hinter `.mp4`,
    sodass `_MEDIA_URL_RE` nicht greift). Also die nackte URL extrahieren (stoppt am `"`).
    """
    m = re.search(r"https?://[^\s\"'<>]+", pw_output or "")
    return m.group(0) if m else ""


def _pw_open_and_loc(url) -> str:
    """playwright-cli: URL headless öffnen (gespeicherte Cookies) und finale location.href lesen."""
    subprocess.run(["playwright-cli", "-s=tuda", "open", "--browser=chromium",
                    "--persistent", url], capture_output=True, text=True, timeout=150)
    ev = subprocess.run(["playwright-cli", "-s=tuda", "eval", "() => location.href"],
                        capture_output=True, text=True, timeout=60)
    return extract_url(ev.stdout)


def resolve_panopto_guid(cmid) -> str:
    """cmid → Panopto-GUID via launch.php (LTI-POST etabliert die Panopto-Session), headless."""
    loc = _pw_open_and_loc(
        f"https://moodle.tu-darmstadt.de/mod/lti/launch.php?id={cmid}&triggerview=0")
    kind, ref = classify_resolved_url(loc)
    if kind == "panopto":
        return ref
    m = _GUID_RE.search(loc)  # Fallback: GUID irgendwo in der finalen URL
    return m.group(0) if m else "NONE"


def resolve_url_module(view_url: str):
    """mod/url-Modul auflösen: view.php?…&redirect=1 öffnen → finale URL klassifizieren.

    Liefert ('panopto', guid) | ('direct', mp4) | (None, None). Deckt Legacy-Queue-
    Einträge (modname=url, nur Moodle-view.php, kein source-Feld) ab — moodleload-MP4
    ODER Panopto-Viewer, je nachdem worauf das url-Modul zeigt.
    """
    if not view_url:
        return None, None
    sep = "&" if "?" in view_url else "?"
    loc = _pw_open_and_loc(f"{view_url}{sep}redirect=1")
    return classify_resolved_url(loc)


def build_item(modul, entry, used_slugs):
    """pending-Eintrag → transcribe_bulk-Item ({source,ref,slug,lang,titel,cmid}) oder (None, grund).

    Robust für neue (source/auth getaggt) UND Legacy-Einträge (nur modname, kein source):
      - moodleload/camtasia      → Direkt-Download der hinterlegten MP4.
      - ws_file                  → WS-fileurl + &token=.
      - lti                      → launch.php → Panopto-GUID.
      - url / unbekannt          → view.php?redirect=1 auflösen → Panopto-GUID ODER moodleload-MP4.
    """
    lang = tb.LANG.get(modul, "de")
    source = entry.get("source")
    modname = entry.get("modname")
    titel = entry.get("name") or entry.get("title") or "Aufzeichnung"
    cmid = entry.get("cmid")

    if source in ("moodleload", "camtasia"):
        url = entry.get("url")
        if not url:
            return None, "kein url-Feld"
        return {"modul": modul, "slug": tb.slugify_media(titel, url, used_slugs), "lang": lang,
                "source": "direct", "ref": url, "cmid": cmid, "titel": titel}, None

    if source == "ws_file":
        url = entry.get("url")
        if not url:
            return None, "kein url-Feld"
        token = _load_token()
        if token:
            sep = "&" if "?" in url else "?"
            url = f"{url}{sep}token={urllib.parse.quote(token)}"
        return {"modul": modul, "slug": tb.slugify_media(titel, entry.get("url"), used_slugs),
                "lang": lang, "source": "direct", "ref": url, "cmid": cmid, "titel": titel}, None

    if source == "lti" or modname == "lti":
        guid = resolve_panopto_guid(cmid)
        if guid == "NONE":
            return None, "GUID-Resolve fehlgeschlagen (Panopto-Cookie/LTI?)"
        return {"modul": modul, "slug": tb.slugify_lti(titel, used_slugs), "lang": lang,
                "source": "panopto", "ref": guid, "cmid": cmid, "titel": titel}, None

    # url / unbekannt → über Redirect auflösen (Panopto-Viewer ODER moodleload-MP4)
    kind, ref = resolve_url_module(entry.get("url"))
    if kind == "panopto":
        return {"modul": modul, "slug": tb.slugify_lti(titel, used_slugs), "lang": lang,
                "source": "panopto", "ref": ref, "cmid": cmid, "titel": titel}, None
    if kind == "direct":
        return {"modul": modul, "slug": tb.slugify_media(titel, ref, used_slugs), "lang": lang,
                "source": "direct", "ref": ref, "cmid": cmid, "titel": titel}, None
    return None, f"url-Resolve fehlgeschlagen (source={source}, modname={modname})"


def _load_token():
    if TOKEN_FILE.exists():
        try:
            return json.loads(TOKEN_FILE.read_text())["token"]
        except Exception:  # noqa: BLE001
            return None
    return None


# ---------------------------------------------------------------------------
# Cookie-Vorabcheck
# ---------------------------------------------------------------------------

def check_panopto():
    r = subprocess.run(["yt-dlp", "--cookies", tb.CK, "--skip-download", "--no-warnings",
                        "--print", "%(title)s",
                        f"https://tu-darmstadt.cloud.panopto.eu/Panopto/Pages/Viewer.aspx?id={PANOPTO_TEST_GUID}"],
                       capture_output=True, text=True)
    return r.returncode == 0 and bool(r.stdout.strip())


def check_cas(sample_url):
    r = subprocess.run(["curl", "-s", "-L", "-b", tb.CK, sample_url, "-o", "/dev/null",
                        "-w", "%{http_code} %{size_download} %{content_type}"],
                       capture_output=True, text=True)
    parts = r.stdout.split()
    return len(parts) >= 3 and parts[0] == "200" and "video" in parts[2]


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description="Transkribiert die offenen _pending.json-Aufzeichnungen.")
    ap.add_argument("--module", nargs="*", default=None, help="nur diese Modul-Slugs")
    ap.add_argument("--limit", type=int, default=0, help="max. so viele Aufzeichnungen")
    ap.add_argument("--dry", action="store_true", help="nur Queue zeigen")
    a = ap.parse_args()

    queues = load_queues(a.module)
    total = sum(len(e) for _, _, e in queues)
    if not total:
        print("✅ Keine offenen Aufzeichnungen in der Queue.", flush=True)
        return
    print(f"Queue: {total} offene Aufzeichnung(en) in {len(queues)} Modul(en).", flush=True)
    for modul, _, entries in queues:
        srcs = ", ".join(sorted({e.get("source", "?") for e in entries}))
        print(f"  {modul:24s} {len(entries):2d} offen  [{srcs}]", flush=True)
        for e in entries:
            print(f"     - {e.get('name')}  ({e.get('source')}/{e.get('auth','?')})", flush=True)
    if a.dry:
        return

    has_cas = any(e.get("auth") == "cas" for _, _, es in queues for e in es)
    sample_cas = next((e["url"] for _, _, es in queues for e in es
                       if e.get("auth") == "cas" and e.get("url")), None)

    # --- Cookie-Vorabcheck ---
    if not check_panopto():
        print("\n🔑 Panopto-Cookie abgelaufen. Bitte am Mac headed neu einloggen "
              "(reference.md §Cookie-Refresh), dann /transcribe erneut.", flush=True)
        sys.exit(3)
    if has_cas and sample_cas and not check_cas(sample_cas):
        print("\n🔑 CAS-Cookie (moodleload) abgelaufen/fehlt. Bitte headed auf eine moodleload-URL "
              "einloggen (reference.md §CAS ≠ SAML), dann /transcribe erneut.", flush=True)
        sys.exit(4)

    # --- Abarbeiten (seriell: GUID-Resolve teilt sich ein Playwright-Profil) ---
    done_total = {"OK": 0, "SUSPECT": 0, "FAIL": 0, "SKIP": 0}
    processed = 0
    for modul, pend, entries in queues:
        used = set()
        done_ids = set()
        for entry in entries:
            if a.limit and processed >= a.limit:
                break
            processed += 1
            item, err = build_item(modul, entry, used)
            if not item:
                print(f"[{processed}] ✗ {modul}/{entry.get('name')} — {err}", flush=True)
                done_total["FAIL"] += 1
                continue
            res = tb.process(item)
            mark = {"OK": "✓", "SUSPECT": "⚠", "FAIL": "✗", "SKIP": "·"}.get(res["status"], "?")
            print(f"[{processed}] {mark} {res['key']} — {res['note']}", flush=True)
            done_total[res["status"]] = done_total.get(res["status"], 0) + 1
            # Nur sauber Fertige aus der Queue nehmen. SUSPECT (z.B. abgeschnitten/
            # Prompt-Echo) + FAIL bleiben pending → Retry beim nächsten Lauf.
            if res["status"] in ("OK", "SKIP"):
                done_ids.add(_identity(entry))
        if done_ids:
            remove_from_queue(pend, done_ids)  # Queue konvergiert auf die echt offenen
        if a.limit and processed >= a.limit:
            break

    tb.commit_vault(f"transkripte: pending-queue gedraint "
                    f"(OK={done_total['OK']} SUSPECT={done_total['SUSPECT']} FAIL={done_total['FAIL']})")
    print(f"\nFERTIG. OK={done_total['OK']} SUSPECT={done_total['SUSPECT']} "
          f"FAIL={done_total['FAIL']} SKIP={done_total['SKIP']}", flush=True)


if __name__ == "__main__":
    main()

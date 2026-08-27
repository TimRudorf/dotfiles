#!/usr/bin/env bash
# PreToolUse(Bash)-Guard: verweigert einmalig einen Bash-Befehl, der eine Datei
# ÄNDERT, für deren Dateityp eine `paths:`-Regel gilt, die in dieser Sitzung
# noch nicht geladen wurde.
#
# Zweck: `paths:`-Regeln (~/.claude/rules/**, .claude/rules im Repo) stellt das
# Harness nur über Read/Edit/Write zu. Ein `sed -i`, ein Heredoc oder eine
# Umleitung ändert dieselbe Datei ohne die Regel — und im Auto- und
# Bypass-Modus rät ein Umgebungshinweis ausdrücklich zu genau diesen Werkzeugen.
# Der Guard erzwingt deshalb einmal je Regel und Sitzung den Umweg über Read.
#
# Eingebunden in settings.json als hooks.PreToolUse Matcher "Bash".
# Aufruf: Hook-Input-JSON auf stdin, Ausgabe permissionDecision auf stdout.
#
# `--index` gibt stattdessen die Liste der Regeln mit ihren Dateitypen aus.
# Der SessionStart-Hook haengt sie in den Kontext, damit die Regeln auch dann
# bekannt sind, wenn die Schreib-Erkennung unten einen Fall nicht erwischt.
#
# Nach der Verweigerung ist die Regel als zugestellt vermerkt: derselbe Befehl
# läuft beim zweiten Versuch durch. Der Guard soll erinnern, nicht einsperren.
# Fail-open: bei jeder Unklarheit exit 0 (nie legitime Arbeit dauerhaft blocken).

set -u

command -v python3 >/dev/null 2>&1 || exit 0

JARVIS_RULE_MODE=""
JARVIS_HOOK_INPUT=""
if [ "${1:-}" = "--index" ]; then
  JARVIS_RULE_MODE="index"
else
  # Das Hook-JSON muss vor dem Heredoc gelesen werden: `python3 <<'PYEOF'`
  # belegt stdin mit dem Programmtext, sonst laese Python sich selbst.
  JARVIS_HOOK_INPUT="$(cat)"
fi
export JARVIS_RULE_MODE JARVIS_HOOK_INPUT

python3 <<'PYEOF' 2>/dev/null || exit 0
import json
import os
import re
import sys
import time

MARKER_ROOT = os.path.expanduser("~/.claude/cache/rule-delivery")
MARKER_MAX_AGE = 7 * 24 * 3600

# Ein Pfad im Befehl heisst nicht, dass er beschrieben wird. Die Erkennung
# trennt deshalb drei Faelle -- alles andere gilt als Lesen. Zu grosszuegig
# waere schlimmer als zu eng: ein Fehltreffer verbraucht den Sitzungsvermerk,
# und die naechste, echte Aenderung liefe stumm durch.
REDIRECT_TARGET = re.compile(r">>?\s*([^\s;|&<>]+)")
INPLACE_TOOL = re.compile(
    r"\bsed\b[^|;&]*\s-i\b"
    r"|\bperl\b[^|;&]*\s-i\b"
    r"|\biconv\b[^|;&]*\s-o\b"
    r"|\b(tee|patch|install|cp|mv|dd)\b"
    r"|\bgit\s+apply\b"
)
# Heredoc-Rumpf und `-c`-Programm eines Interpreters: nur was DORT steht, ist
# sein Gegenstand -- Pfade daneben sind Argumente der umgebenden Shell.
INTERPRETER_BODY = re.compile(
    r"<<-?\s*'?\"?(\w+)'?\"?\s*\n(.*?)\n\s*\1"
    r"|-c\s+'([^']*)'"
    r"|-c\s+\"([^\"]*)\"",
    re.S,
)
WRITE_IN_BODY = re.compile(
    r"open\([^)]*['\"][wax]|\.write\(|\.writelines\(|shutil\.(copy|move)"
    r"|os\.(rename|replace)|>>?\s*['\"]?\S"
)


def read_hook_input():
    try:
        data = json.loads(os.environ.get("JARVIS_HOOK_INPUT", ""))
    except Exception:
        return "", "", ""
    tool_input = data.get("tool_input") or {}
    return (
        tool_input.get("command") or "",
        data.get("session_id") or "",
        data.get("cwd") or "",
    )


def rule_dirs(cwd):
    dirs = [os.path.expanduser("~/.claude/rules")]
    # Repo-eigene Regeln gelten zusaetzlich, sobald in einem Repo gearbeitet wird.
    probe = cwd
    while probe and probe != "/":
        candidate = os.path.join(probe, ".claude", "rules")
        if os.path.isdir(candidate):
            dirs.append(candidate)
            break
        probe = os.path.dirname(probe)
    return dirs


def extensions_of(rule_path):
    """Endungen aus dem `paths:`-Frontmatter, leer wenn die Regel immer gilt."""
    try:
        with open(rule_path, encoding="utf-8", errors="replace") as handle:
            head = handle.read(2048)
    except OSError:
        return set()
    match = re.search(r"^---\s*\n(.*?)\n---", head, re.S)
    if not match:
        return set()
    # Der abschliessende Zeilenumbruch gehoert zum Trenner: ohne ihn faellt der
    # letzte Listeneintrag aus dem Treffer (delphi.md verlor so `dfm`).
    block = re.search(r"^paths:\s*\n((?:\s*-\s*.*\n)+)", match.group(1) + "\n", re.M)
    if not block:
        return set()
    return set(re.findall(r"\*\.([A-Za-z0-9]+)", block.group(1)))


def collect_rules(cwd):
    rules = {}
    for directory in rule_dirs(cwd):
        for root, _dirs, files in os.walk(directory, followlinks=True):
            for name in sorted(files):
                if not name.endswith(".md"):
                    continue
                path = os.path.join(root, name)
                exts = extensions_of(path)
                if exts:
                    rules[path] = exts
    return rules


def written_paths(cmd, known_exts):
    """Pfade im Befehl, die er nach bestem Wissen veraendert."""
    if not known_exts:
        return set()
    pattern = re.compile(
        r"[\w./~$@+-]+\.(" + "|".join(sorted(known_exts)) + r")\b", re.I
    )
    targets = set()

    for target in REDIRECT_TARGET.findall(cmd):
        if pattern.fullmatch(target):
            targets.add(target)

    for segment in re.split(r"[;&|]+", cmd):
        if INPLACE_TOOL.search(segment):
            targets.update(m.group(0) for m in pattern.finditer(segment))

    for match in INTERPRETER_BODY.finditer(cmd):
        body = match.group(2) or match.group(3) or match.group(4) or ""
        if WRITE_IN_BODY.search(body):
            targets.update(m.group(0) for m in pattern.finditer(body))

    return targets


def prune_markers(now):
    try:
        for entry in os.listdir(MARKER_ROOT):
            path = os.path.join(MARKER_ROOT, entry)
            if now - os.path.getmtime(path) > MARKER_MAX_AGE:
                for name in os.listdir(path):
                    os.remove(os.path.join(path, name))
                os.rmdir(path)
    except OSError:
        pass


def print_index(cwd):
    rules = collect_rules(cwd)
    if not rules:
        return
    print("## Regeln mit Dateitypbindung\n")
    print(
        "Diese Regeln kommen nur in den Kontext, wenn eine passende Datei "
        "ueber Read/Edit/Write angefasst wird. Wer sie ueber Bash aendert "
        "(sed, Heredoc, Umleitung), arbeitet ohne sie:\n"
    )
    for path, exts in sorted(rules.items()):
        name = os.path.basename(path)[:-3]
        print("- **%s** — %s" % (name, ", ".join(sorted(exts))))


def main():
    cmd, session_id, cwd = read_hook_input()
    if os.environ.get("JARVIS_RULE_MODE") == "index":
        print_index(os.getcwd())
        return
    # Ohne Sitzungskennung liesse sich nicht vermerken, dass eine Regel schon
    # zugestellt wurde -- der Guard wuerde endlos verweigern.
    if not cmd or not session_id:
        return

    rules = collect_rules(cwd)
    if not rules:
        return

    all_exts = set()
    for exts in rules.values():
        all_exts |= exts
    targets = written_paths(cmd, all_exts)
    if not targets:
        return

    touched_exts = {t.rsplit(".", 1)[-1].lower() for t in targets}
    marker_dir = os.path.join(MARKER_ROOT, re.sub(r"[^\w-]", "_", session_id))

    pending = []
    for path, exts in sorted(rules.items()):
        if not ({e.lower() for e in exts} & touched_exts):
            continue
        marker = os.path.join(marker_dir, re.sub(r"[^\w.-]", "_", path))
        if os.path.exists(marker):
            continue
        pending.append((path, marker))

    if not pending:
        return

    try:
        os.makedirs(marker_dir, exist_ok=True)
        for _path, marker in pending:
            open(marker, "w").close()
        prune_markers(time.time())
    except OSError:
        # Laesst sich der Vermerk nicht schreiben, wuerde der Guard bei jedem
        # Versuch erneut verweigern. Dann lieber durchlassen.
        return

    names = ", ".join(os.path.basename(p) for p, _ in pending)
    files = ", ".join(sorted(targets))
    reason = (
        "Regel noch nicht zugestellt: %s (gilt fuer %s).\n\n"
        "paths-gebundene Regeln kommen nur ueber Read/Edit/Write in den "
        "Kontext -- eine Aenderung ueber Bash umgeht sie. Lies die Datei "
        "einmal mit Read, oder aendere sie gleich mit Edit/Write. Danach "
        "laeuft derselbe Befehl durch.\n\n"
        "Betroffen: %s\nRegeldatei(en): %s"
        % (names, ", ".join(sorted(touched_exts)), files,
           ", ".join(p for p, _ in pending))
    )

    print(reason, file=sys.stderr)
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        },
    }))


main()
PYEOF

exit 0

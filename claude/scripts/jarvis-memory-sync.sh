#!/usr/bin/env bash
# Stop-Hook: committet und pusht, was Claudes Auto-Memory geschrieben hat.
#
# Nötig, weil Auto-Memory NICHT über Write/Edit läuft, sondern intern schreibt —
# der PostToolUse-Autosync (matcher Write|Edit|MultiEdit) sieht davon nichts.
# Ohne diesen Hook bliebe alles Gelernte auf dem Rechner liegen, auf dem es
# entstanden ist, und die anderen Hosts wüssten nichts davon.
#
# Fail-safe: jeder Fehler endet mit exit 0 und ohne Ausgabe. Ein Sitzungsende
# darf nie an einem Sync scheitern.
set -u

VAULT="${VAULT:-}"
for c in "$HOME/jarvis-wiki" "/workspace/wiki" "$HOME/Documents/jarvis-wiki"; do
  [ -z "$VAULT" ] && [ -d "$c/.git" ] && VAULT="$c"
done
[ -n "$VAULT" ] || exit 0

cd "$VAULT" 2>/dev/null || exit 0
git diff --quiet -- memory/ 2>/dev/null && git diff --cached --quiet -- memory/ 2>/dev/null \
  && [ -z "$(git ls-files --others --exclude-standard memory/ 2>/dev/null)" ] && exit 0

git add -A memory/ 2>/dev/null || exit 0
git diff --cached --quiet -- memory/ 2>/dev/null && exit 0

host="${JARVIS_HOST:-$(hostname -s 2>/dev/null || echo unbekannt)}"
git commit -q -m "memory: auto-sync (via $host)" -- memory/ 2>/dev/null || exit 0

# Erst holen, dann schieben. MEMORY.md ist per .gitattributes auf union
# gestellt, damit gleichzeitige Einträge zweier Hosts sich nicht gegenseitig
# blockieren — im schlimmsten Fall steht eine Zeile doppelt, und die nächste
# Sitzung räumt sie beim Kürzen weg.
if ! git pull --rebase --quiet 2>/dev/null; then
  git rebase --abort 2>/dev/null
  exit 0
fi
git push --quiet 2>/dev/null || true
exit 0

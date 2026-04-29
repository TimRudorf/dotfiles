#!/usr/bin/env bash
# PreToolUse-Hook: blockt jeden Aufruf gegen den claude.ai Google-Calendar-MCP.
# Tims Kalender ist Nextcloud (CalDAV), nicht Google. Siehe Vault:
#   tim/feedback/kalender-nie-google.md
#   referenz/calendar-nextcloud.md
#
# Wird in ~/dotfiles/claude/settings.json als hooks.PreToolUse mit Matcher
#   "mcp__claude_ai_Google_Calendar__.*"
# eingebunden. Exit 2 + stderr blockt den Tool-Call und zeigt Claude die
# Fehlermeldung — so kann das Modell sofort umsteuern auf CalDAV.
#
# Stdin: JSON {tool_name, tool_input, ...}. Wir lesen es nur weg.

cat >/dev/null 2>&1 || true

cat >&2 <<'EOF'
BLOCKED: Google Calendar MCP ist für Tim tabu.

Tims Kalender liegt auf Nextcloud (CalDAV), nicht Google. Auch wenn der
Connector "claude.ai Google Calendar" im Tool-Listing auftaucht — nicht
nutzen, nicht authentifizieren.

Stattdessen: Skill `nextcloud-calendar` (Trigger: kalender, termin, eintragen).
Endpoint und Auth siehe Vault `referenz/calendar-nextcloud.md`.

Privat:    $NC_PRIVATE_HOST/remote.php/dav/calendars/$NC_PRIVATE_USER/
Dienstlich: $NC_WORK_HOST/remote.php/dav/calendars/$NC_WORK_USER/
EOF

exit 2

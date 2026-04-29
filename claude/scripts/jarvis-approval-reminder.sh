#!/usr/bin/env bash
# PreToolUse-Hook: läuft VOR jedem mcp__bridge__request_approval-Call und
# druckt eine Reminder-Liste auf stderr — ohne den Call zu blocken (Exit 0).
#
# Zweck: Modell hat öfter den Reflex, bei intern-only Aktionen Approval
# anzufordern (Bulk-Edit auf Tims Vault/Kalender/Tasks), obwohl
# `tim/feedback/eigenstaendigkeit.md` und CLAUDE.md klar sagen: Approval
# nur bei Außenwirkung. Die stderr-Botschaft kalibriert den Reflex.
#
# Hard-block wäre falsch — manchmal ist Approval genau richtig (externe
# Mails, shared destructive). Wir bremsen nur, wir verbieten nicht.
#
# Wird in ~/dotfiles/claude/settings.json als hooks.PreToolUse mit
# matcher "mcp__bridge__request_approval" eingebunden.

cat >/dev/null 2>&1 || true   # stdin wegfangen

cat >&2 <<'EOF'
[approval-reminder] Approval-Pflicht ist ausschließlich für Außenwirkung:
  - externe Kommunikation (Zammad-Mail, Teams, Slack, Mails an Dritte)
  - Push/Deploy auf shared/Kunden-Systemen
  - Bestellungen, Termin-Buchungen, billing API calls
  - Bulk-Writes auf shared DBs

NICHT approval-pflichtig (auf Tims eigenen Systemen einfach machen):
  - Vault-Writes, lokale Edits, eigene Repos
  - Nextcloud-Kalender (lesen/anlegen/ändern/löschen, auch bulk)
  - Nextcloud-Tasks (auch bulk)

Wenn der jetzige Call NICHT in den Außenwirkungs-Bucket fällt:
abbrechen, einfach machen, danach kurz berichten.
EOF

exit 0

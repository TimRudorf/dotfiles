#!/usr/bin/env bash
# Install (or refresh) the launchd agent that runs sync-from-remote.sh every
# 2 minutes on macOS. Replaces the cron-based approach because /usr/sbin/cron
# needs Full Disk Access on modern macOS, which is fragile.
# Idempotent.

set -euo pipefail

[[ "$(uname)" == "Darwin" ]] || { echo "macOS only"; exit 1; }

LABEL="com.timrudorf.dotfiles-sync"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
SCRIPT="$HOME/dotfiles/scripts/sync-from-remote.sh"

mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-lc</string>
        <string>${SCRIPT}</string>
    </array>
    <key>StartInterval</key>
    <integer>120</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/.cache/dotfiles-sync.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.cache/dotfiles-sync.stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
        <key>HOME</key>
        <string>${HOME}</string>
    </dict>
</dict>
</plist>
EOF

# Bootstrap (or re-bootstrap) the agent
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl enable "gui/$(id -u)/${LABEL}"

# Remove any stale cron entry for the same script — launchd is now authoritative
if crontab -l 2>/dev/null | grep -q 'sync-from-remote.sh'; then
  crontab -l | grep -v 'sync-from-remote.sh' | crontab -
  echo "✓ removed stale cron entry"
fi

echo "✓ launchd agent ${LABEL} installed (every 120s, runs at load)"
launchctl print "gui/$(id -u)/${LABEL}" 2>/dev/null | grep -E 'state|last exit'  || true

---
name: sudo-askpass
description: This skill should be used when Claude needs to run a command with sudo, encounters a "sudo: a terminal is required" error, or the user asks to "run as root" in a non-interactive terminal.
user-invocable: false
---

# Sudo Askpass

When running commands that require `sudo` in a non-interactive environment (no TTY for password input), use the graphical askpass helper:

```bash
SUDO_ASKPASS=/usr/lib/ssh/ssh-askpass sudo -A <command>
```

The `-A` flag tells sudo to use `$SUDO_ASKPASS` for the password prompt instead of the terminal. This is necessary because Claude Code cannot provide interactive terminal input for sudo password prompts.

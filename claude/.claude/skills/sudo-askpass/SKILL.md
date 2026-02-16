# Sudo Askpass

When running commands that require `sudo` in a non-interactive environment (no TTY for password input), use the graphical askpass helper:

```bash
SUDO_ASKPASS=/usr/lib/ssh/ssh-askpass sudo -A <command>
```

The `-A` flag tells sudo to use `$SUDO_ASKPASS` for the password prompt instead of the terminal. This is necessary because Claude Code cannot provide interactive terminal input for sudo password prompts.

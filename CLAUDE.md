# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal, cross-platform dotfiles managed via GNU Stow. Currently includes configs for Arch Linux + Hyprland, but designed to support any platform (including macOS).

## Deploying

Each subdirectory is a stow package structured as `<name>/.config/<name>/...`. Deploy with:
```bash
stow -t ~ <package-name>
```

Shell dotfiles (`shell/`) are an exception — they stow directly into `$HOME` (e.g. `.zshrc`, `.alias.sh`).

## Key Conventions

- **Theme**: Catppuccin Mocha everywhere
- **Shell**: zsh + oh-my-zsh + Powerlevel10k; zoxide (`z`), eza (`ls`), bat (`cat`), fzf
- **Editor**: Neovim with LazyVim; 4-space indentation; formatters via conform.nvim
- **Hyprland config is modular**: `hyprland.conf` sources sub-configs — edit the specific file, not the main one
- **Machine-specific overrides**: Use `*.local.conf` files (gitignored) for hardware-specific settings
- **Language**: Mixed German/English in comments and messages

## Git Workflow

- `main` is protected — no direct pushes
- Always work on feature branches and merge via PR

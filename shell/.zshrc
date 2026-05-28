# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export EDITOR=nvim

# oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
export ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# Powerlevel10k
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# NVM (lazy loaded via shell init)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# fzf
source <(fzf --zsh)

# Aliases
source ~/.alias.sh

# Work helpers (optional, skip if missing)
[[ -f ~/.edp_helpers.sh ]] && source ~/.edp_helpers.sh

# sops + age (where to find the age private key — macOS default is elsewhere)
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"

# Secrets & API tokens (Claude Code Skills) — managed via sops, decrypted by scripts/decrypt-env.sh
[[ -f ~/.env ]] && source ~/.env

# Local bin
export PATH="$HOME/.local/bin:$PATH"

# LSP for Claude Code
export ENABLE_LSP_TOOL=1

# OS-specific config
[[ -f ~/.zshrc.$(uname | tr '[:upper:]' '[:lower:]') ]] && source ~/.zshrc.$(uname | tr '[:upper:]' '[:lower:]')

export LC_CTYPE=en_US.UTF-8

# zoxide — muss laut eigener Prüfung als letztes initialisiert werden.
# _ZO_DOCTOR=0 unterdrückt den False-Positive-Doctor-Check: Claude Codes
# Bash-Wrapper registriert eigene precmd/chpwd-Hooks nach zoxide, wodurch
# der Check trotz korrekter Reihenfolge anschlägt.
export _ZO_DOCTOR=0
eval "$(zoxide init zsh)"

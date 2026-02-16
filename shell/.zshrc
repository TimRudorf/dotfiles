# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Editor setzen
export EDITOR=nvim

# oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
export ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  )

source $ZSH/oh-my-zsh.sh

# Powerlevel10k
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# matlab fix
export LD_LIBRARY_PATH=$HOME/matlab/gnutls/usr/lib/:;

# Bildschirmfreigabe
export XDG_CURRENT_DESKTOP=Hyprland
export MOZ_ENABLE_WAYLAND=1

# zoxide
eval "$(zoxide init zsh)"

# fzf
source <(fzf --zsh)

# Alias
source ~/.alias.sh

# EDP Helpers
source ~/.edp_helpers.sh

# LoaclBin
export PATH="$HOME/.local/bin:$PATH"

# LSP Server für Claude Code
export ENABLE_LSP_TOOL=1

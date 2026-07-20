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

# edp-ctrl Shell-Completions (cobra) — gecacht auf fpath, auto-regeneriert wenn das
# Binary neuer ist als der Cache (z.B. nach `edp-ctrl update`). Muss VOR compinit laufen
# (oh-my-zsh.sh, direkt darunter). Absoluter Pfad, da ~/.local/bin erst spaeter in PATH kommt.
# Kein-op auf Hosts ohne edp-ctrl.
_edpctrl_bin="$HOME/.local/bin/edp-ctrl"
if [[ -x "$_edpctrl_bin" ]]; then
  _edpctrl_compdir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/completions"
  if [[ ! -s "$_edpctrl_compdir/_edp-ctrl" || "$_edpctrl_bin" -nt "$_edpctrl_compdir/_edp-ctrl" ]]; then
    mkdir -p "$_edpctrl_compdir"
    "$_edpctrl_bin" completion zsh > "$_edpctrl_compdir/_edp-ctrl" 2>/dev/null \
      && rm -f "$HOME"/.zcompdump* 2>/dev/null   # Dump verwerfen, damit die Completion sofort greift
  fi
  fpath=("$_edpctrl_compdir" $fpath)
  unset _edpctrl_bin _edpctrl_compdir
fi

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

# EDP Dev-VM — die alte edp()-Shell wurde durch das `edp-ctrl`-CLI abgeloest
# (edp-ctrl dev compile/test/log/service). edp-ctrl selbst nutzt sein Profil; diese
# beiden Vars bleiben fuer edp-design-loop/playwright (rohe VM-IP + lokaler Projektpfad).
export EDP_VM_HOST="${EDP_VM_HOST:-eifert-dev}"
export EDP_PROJECT_ROOT="${EDP_PROJECT_ROOT:-$HOME/dev/EDP}"

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

# UTF-8-ctype erzwingen. macOS braucht en_US.UTF-8; auf Linux-Hosts, die diese Locale
# nicht generiert haben (z.B. Arch/Poseidon mit nur de_DE.UTF-8), wuerde das Setzen dazu
# fuehren, dass Tools wie manpath waehrend der Init auf die Konsole warnen ("can't set the
# locale") — was den p10k-Instant-Prompt stoert. Daher nur setzen, wenn wirklich vorhanden;
# sonst greift das (ebenfalls UTF-8-faehige) System-Locale.
if (( $+commands[locale] )) && locale -a 2>/dev/null | grep -qiE '^en_US\.utf-?8$'; then
  export LC_CTYPE=en_US.UTF-8
fi

# zoxide — muss laut eigener Prüfung als letztes initialisiert werden.
# _ZO_DOCTOR=0 unterdrückt den False-Positive-Doctor-Check: Claude Codes
# Bash-Wrapper registriert eigene precmd/chpwd-Hooks nach zoxide, wodurch
# der Check trotz korrekter Reihenfolge anschlägt.
export _ZO_DOCTOR=0
eval "$(zoxide init zsh)"

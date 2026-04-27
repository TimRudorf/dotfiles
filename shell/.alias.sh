alias cd="z"
alias ls="eza -la"
alias lg="lazygit"
alias lsql="lazysql"
alias cat="bat"

# Edit shared sops-encrypted dotenv (auto-sets dotenv format)
senv() { sops --input-type=dotenv --output-type=dotenv "${1:-$HOME/dotfiles/secrets/env.sops}"; }

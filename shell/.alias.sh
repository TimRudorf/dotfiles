alias cd="z"
alias ls="eza -la"
alias lg="lazygit"
alias lsql="lazysql"
alias cat="bat"
alias claudia="claude --dangerously-skip-permissions"

# Edit shared sops-encrypted dotenv. If the canonical file changed, auto-commits
# and pushes — uses an ephemeral branch + auto-merged PR when on main (because
# main is protection-protected), and refreshes the local ~/.env immediately so
# the new values are usable in this shell after `source ~/.env`. The VM picks
# up the change via the cron-based auto-sync within ~2 min.
senv() {
  local file="${1:-$HOME/dotfiles/secrets/env.sops}"
  local rc
  sops --input-type=dotenv --output-type=dotenv "$file"
  rc=$?
  # sops returns 200 when content didn't change in the editor — not an error;
  # an earlier-staged change to the file may still need to be pushed.
  if (( rc != 0 && rc != 200 )); then
    return $rc
  fi

  # Only auto-push for the canonical secrets file
  [[ "$file" == "$HOME/dotfiles/secrets/env.sops" ]] || return 0

  (
    cd "$HOME/dotfiles" || exit 0
    git diff --quiet -- secrets/env.sops && exit 0

    local branch autobranch=""
    branch=$(git symbolic-ref --short HEAD)
    if [[ "$branch" == "main" ]]; then
      autobranch="auto/sops-$(date +%s)"
      git checkout -q -b "$autobranch"
    else
      echo "⚠ on '$branch' (not main) — pushing to that branch, no auto-deploy to hosts"
    fi

    git add secrets/env.sops
    git -c gpg.format=ssh -c commit.gpgsign=false commit -q -m "secrets: rotate via senv"
    git -c credential.helper="!f() { echo username=TimRudorf; echo password=$GH_PRIVATE_TOKEN; }; f" \
        push -q -u origin HEAD || { echo "✗ push failed"; exit 1; }

    if [[ -n "$autobranch" ]]; then
      GH_TOKEN="$GH_PRIVATE_TOKEN" gh pr create --base main --head "$autobranch" \
        --title "secrets: rotate via senv" \
        --body "Automated rotation via \`senv\`." >/dev/null || { echo "✗ PR create failed"; exit 1; }
      GH_TOKEN="$GH_PRIVATE_TOKEN" gh pr merge "$autobranch" --merge --delete-branch >/dev/null \
        || { echo "✗ PR merge failed"; exit 1; }
      git checkout -q main && git pull -q --ff-only
      "$HOME/dotfiles/scripts/decrypt-env.sh" >/dev/null && \
        echo "✓ pushed + merged; ~/.env updated; VM syncs via cron in ≤2 min — run 'source ~/.env' for new values in this shell"
    else
      echo "✓ pushed to $branch"
    fi
  )
}

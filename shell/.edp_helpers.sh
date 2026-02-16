# Helper functions for edpweb development (bash + zsh compatible)
# These rely on SSH host aliases configured in ~/.ssh/config

# --- Configuration (override via env vars if needed) ---
EDP_VM_HOST="${EDP_VM_HOST:-eifert-dev}"
EDP_VM_DIR="${EDP_VM_DIR:-\\\\192.168.122.1\\edp\\edpweb}"
EDP_SMB_SHARE="${EDP_SMB_SHARE:-\\\\192.168.122.1\\edp}"
EDP_SMB_USER="${EDP_SMB_USER:-tim}"
EDP_PROJECT_ROOT="${EDP_PROJECT_ROOT:-$HOME/Develop/EDP}"
EDP_VM_NAME="${EDP_VM_NAME:-EifertSystem_Development}"

# Run a command on the VM with SMB share connected (single SSH session)
_edp_vm_cmd() {
  ssh "$EDP_VM_HOST" "net use ${EDP_SMB_SHARE} PoseidonEDP /user:${EDP_SMB_USER} 2>nul & $*" | iconv -f CP850 -t UTF-8 2>/dev/null
}

# Sync current repo to Windows VM
rsyncdev() {
  echo "Hinweis: SMB-Share aktiv — rsyncdev normalerweise nicht nötig." >&2
  echo "         Nur als Fallback nutzen wenn Share nicht gemountet." >&2
  echo "" >&2
  local cwd
  cwd="$(pwd -P)"

  if [[ "$cwd" != "$EDP_PROJECT_ROOT" && "$cwd" != "$EDP_PROJECT_ROOT"/* ]]; then
    echo "rsyncdev: must be within $EDP_PROJECT_ROOT" >&2
    return 1
  fi

  local dir
  dir="$(basename "$PWD")"
  local changesfile
  changesfile="$(mktemp)"

  rsync -rltD --delete --itemize-changes \
    --exclude '.git/' \
    --exclude 'edpweb.exe' \
    --exclude 'edpweb.log' \
    --exclude 'compile.log' \
    --exclude 'html/' \
    --exclude 'Win64/' \
    --exclude 'Logs/' \
    --exclude 'rechte/' \
    --exclude 'keys/' \
    --exclude 'setup/' \
    --exclude 'public/css/global/statusfarben.css' \
    --no-perms --no-owner --no-group --chmod=ugo=rwX \
    ./ "${EDP_VM_HOST}:/cygdrive/c/Users/Admin/Entwicklung/${dir}/" >"$changesfile"

  if [[ -s "$changesfile" ]]; then
    tail -n +2 "$changesfile"
  else
    echo "rsync: no changes"
  fi
  rm -f "$changesfile"
}

# Control/Build edpweb service on Windows VM
edpweb() {
  case "${1:-}" in
    start|stop)
      ssh "$EDP_VM_HOST" "net $1 edpwebservice" | iconv -f CP850 -t UTF-8 2>/dev/null
      ;;
    status)
      ssh "$EDP_VM_HOST" "sc query edpwebservice" | iconv -f CP850 -t UTF-8 2>/dev/null
      ;;
    build)
      _edp_vm_cmd "cmd /c \"pushd ${EDP_VM_DIR} && compile.cmd -b -cfg:Release -p:Win64\""
      ;;
    compile)
      _edp_vm_cmd "cmd /c \"pushd ${EDP_VM_DIR} && compile.cmd -c -cfg:Release -p:Win64\""
      ;;
    log)
      shift
      local level=""
      local text_parts=()
      while (($#)); do
        case "$1" in
          --level=*|-l=*) level="${1#*=}" ;;
          --level|-l)     shift; level="${1:-}" ;;
          *)              text_parts+=("$1") ;;
        esac
        shift
      done
      local filter="${text_parts[*]}"
      LC_ALL=C ssh "$EDP_VM_HOST" "net use ${EDP_SMB_SHARE} PoseidonEDP /user:${EDP_SMB_USER} 2>nul & powershell -NoProfile -Command \"Get-Content -Path '${EDP_VM_DIR}\\edpweb.log' -Tail 200 -Wait\"" \
        | LC_ALL=C awk -v f="$filter" -v lvl="$level" '
          BEGIN {
            use    = (length(f)   > 0)
            useLvl = (length(lvl) > 0)
            esc    = sprintf("%c", 27)
            red    = esc "[31m"
            cyan   = esc "[36m"
            reset  = esc "[0m"
            levelfilt = tolower(lvl)
          }
          NR == 1 { system("printf \"\\033c\"") }
          {
            line = $0; sub(/\r$/, "", line)
            l = tolower(line)
            if (use && l !~ tolower(f)) next

            level = ""
            split(line, parts, /\|/)
            if (length(parts) >= 3) {
              level = parts[3]
              gsub(/^[ \t]+|[ \t]+$/, "", level)
              level = tolower(level)
            }
            if (useLvl && level != levelfilt) next

            if      (level == "fehler") printf("%s%s%s\n", red, line, reset)
            else if (level == "debug")  printf("%s%s%s\n", cyan, line, reset)
            else                        print line
            fflush()
          }'
      ;;
    compilelog)
      LC_ALL=C ssh "$EDP_VM_HOST" "net use ${EDP_SMB_SHARE} PoseidonEDP /user:${EDP_SMB_USER} 2>nul & powershell -NoProfile -Command \"Get-Content -Path '${EDP_VM_DIR}\\compile.log' -Tail 200 -Wait\"" \
        | LC_ALL=C awk 'NR==1 { system("printf \"\\033c\"") } { sub(/\r$/,""); print; fflush() }'
      ;;
    startuplog)
      _edp_vm_cmd "cmd /c \"pushd ${EDP_VM_DIR} && type startup_error.log\""
      ;;
    *)
      echo "Usage: edpweb {start|stop|status|build|compile|log|compilelog|startuplog}"
      return 1
      ;;
  esac
}

# VM lifecycle helper
devvm() {
  case "${1:-}" in
    start)      virsh start "$EDP_VM_NAME" ;;
    stop)       virsh shutdown "$EDP_VM_NAME" ;;
    force-stop) virsh destroy "$EDP_VM_NAME" ;;
    status)     virsh domstate "$EDP_VM_NAME" ;;
    console)    virt-viewer --attach "$EDP_VM_NAME" & ;;
    ip)         virsh domifaddr "$EDP_VM_NAME" ;;
    *)
      echo "Usage: devvm {start|stop|force-stop|status|console|ip}"
      return 1
      ;;
  esac
}

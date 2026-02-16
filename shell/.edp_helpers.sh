# Helper functions for edpweb development (bash + zsh compatible)
# These rely on SSH host aliases configured in ~/.ssh/config

# --- Configuration (override via env vars if needed) ---
EDP_VM_HOST="${EDP_VM_HOST:-eifert-dev}"
EDP_VM_DIR="${EDP_VM_DIR:-C:\\Users\\Admin\\Entwicklung\\edpweb}"
EDP_PROJECT_ROOT="${EDP_PROJECT_ROOT:-$HOME/Develop/EDP}"
EDP_HYPERVISOR="${EDP_HYPERVISOR:-zeus}"
EDP_VM_NAME="${EDP_VM_NAME:-EifertSystem_Development}"

# Sync current repo to Windows VM
rsyncdev() {
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
      ssh "$EDP_VM_HOST" "net $1 edpwebservice"
      ;;
    status)
      ssh "$EDP_VM_HOST" "sc query edpwebservice"
      ;;
    build)
      ssh "$EDP_VM_HOST" "cmd /c \"cd /d ${EDP_VM_DIR} && compile.cmd -b -cfg:Release -p:Win64\""
      ;;
    compile)
      ssh "$EDP_VM_HOST" "cmd /c \"cd /d ${EDP_VM_DIR} && compile.cmd -c -cfg:Release -p:Win64\""
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
      LC_ALL=C ssh "$EDP_VM_HOST" "powershell -NoProfile -Command \"Get-Content -Path '${EDP_VM_DIR}\\edpweb.log' -Tail 200 -Wait\"" \
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
      LC_ALL=C ssh "$EDP_VM_HOST" "powershell -NoProfile -Command \"Get-Content -Path '${EDP_VM_DIR}\\compile.log' -Tail 200 -Wait\"" \
        | LC_ALL=C awk 'NR==1 { system("printf \"\\033c\"") } { sub(/\r$/,""); print; fflush() }'
      ;;
    startuplog)
      ssh "$EDP_VM_HOST" "cmd /c \"cd /d ${EDP_VM_DIR} && type startup_error.log\""
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
    start)      ssh "$EDP_HYPERVISOR" "virsh start '$EDP_VM_NAME'" ;;
    stop)       ssh "$EDP_HYPERVISOR" "virsh shutdown '$EDP_VM_NAME'" ;;
    force-stop) ssh "$EDP_HYPERVISOR" "virsh destroy '$EDP_VM_NAME'" ;;
    status)     ssh "$EDP_HYPERVISOR" "virsh domstate '$EDP_VM_NAME'" ;;
    console)    ssh -t "$EDP_HYPERVISOR" "virsh console '$EDP_VM_NAME'" ;;
    *)
      echo "Usage: devvm {start|stop|force-stop|status|console}"
      return 1
      ;;
  esac
}

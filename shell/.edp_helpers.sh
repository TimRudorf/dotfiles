# Common helper functions for edpweb (bash + zsh compatible)

# Sync current repo to Windows-VM without carrying POSIX ACL/owner info
rsyncdev() {
  local allowed_root="$HOME/Develop/EDP"
  local cwd
  cwd="$(pwd -P)"

  # Only allow syncing from the specified project tree
  if [[ "$cwd" != "$allowed_root" && "$cwd" != "$allowed_root"/* ]]; then
    echo "rsyncdev: Current directory must be within $allowed_root" >&2
    return 1
  fi

  local dir
  dir="$(basename "$PWD")"
  local changesfile
  changesfile="$(mktemp)"
  # Protect remote artifacts/logs from deletion while still syncing the rest.
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
    ./ eifert-dev:"/cygdrive/c/Users/Admin/Entwicklung/${dir}/" >"$changesfile"
  if [[ -s "$changesfile" ]]; then
    tail -n +2 "$changesfile"
  else
    echo "rsync: keine Änderungen"
  fi
  rm -f "$changesfile"
}

# Control/Build edpweb service on Windows-VM
edpweb() {
  local remote_dir="C:\\Users\\Admin\\Entwicklung\\edpweb"
  case "$1" in
    start|stop)
      ssh eifert-dev "net $1 edpwebservice"
      ;;
    status)
      ssh eifert-dev "sc query edpwebservice"
      ;;
    build)
      ssh eifert-dev "cmd /c \"cd /d ${remote_dir} && compile.cmd -b -cfg:Release -p:Win64\""
      ;;
    compile)
      ssh eifert-dev "cmd /c \"cd /d ${remote_dir} && compile.cmd -c -cfg:Release -p:Win64\""
      ;;
    log)
      # Parse optional level filter and optional free-text filter.
      shift # drop "log"
      local level=""
      local text_parts=()
      while (($#)); do
        case "$1" in
          --level=*|-l=*)
            level="${1#*=}"
            ;;
          --level|-l)
            shift
            level="${1:-}"
            ;;
          *)
            text_parts+=("$1")
            ;;
        esac
        shift
      done
      local filter="${text_parts[*]}"
      # Stream log plain from Windows VM; filter/color locally with awk (ANSI; force LC_ALL=C to avoid multibyte issues).
      LC_ALL=C ssh eifert-dev "powershell -NoProfile -Command \"Get-Content -Path '${remote_dir}\\edpweb.log' -Tail 200 -Wait\"" | LC_ALL=C awk -v f="$filter" -v lvl="$level" 'BEGIN { use=(length(f)>0); useLvl=(length(lvl)>0); esc=sprintf("%c",27); red=esc"[31m"; cyan=esc"[36m"; reset=esc"[0m"; levelfilt=tolower(lvl); } NR==1 { system("printf \"\\033c\""); } { line=$0; sub(/\r$/,"",line); l=tolower(line); if (use && l !~ tolower(f)) next; level=""; split(line, parts, /\|/); if (length(parts) >= 3) { level=parts[3]; gsub(/^[ \t]+|[ \t]+$/, "", level); level=tolower(level); } if (useLvl && level != levelfilt) next; if (level=="fehler") printf("%s%s%s\n", red, line, reset); else if (level=="debug") printf("%s%s%s\n", cyan, line, reset); else print line; fflush(); }'
      ;;
    compilelog)
      # Stream compile log live and clear screen once the first line arrives.
      LC_ALL=C ssh eifert-dev "powershell -NoProfile -Command \"Get-Content -Path '${remote_dir}\\compile.log' -Tail 200 -Wait\"" | LC_ALL=C awk 'NR==1 { system("printf \"\\033c\""); } { sub(/\r$/,""); print; fflush(); }'
      ;;
    startuplog)
      ssh eifert-dev "cmd /c \"cd /d ${remote_dir} && type startup_error.log\""
      ;;
    *)
      echo "Usage: edpweb {start|stop|status|build|compile|log|compilelog|startuplog}"
      return 1
      ;;
  esac
}

# VM lifecycle helper
devvm() {
  local vm="EifertSystem_Development"
  case "$1" in
    start)
      ssh zeus "virsh start '$vm'"
      ;;
    stop)
      ssh zeus "virsh shutdown '$vm'"
      ;;
    force-stop)
      ssh zeus "virsh destroy '$vm'"
      ;;
    status)
      ssh zeus "virsh domstate '$vm'"
      ;;
    console)
      ssh -t zeus "virsh console '$vm'"
      ;;
    *)
      echo "Usage: devvm {start|stop|force-stop|status|console}"
      return 1
      ;;
  esac
}

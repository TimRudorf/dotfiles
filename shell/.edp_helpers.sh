# Helper functions for EDP development (bash + zsh compatible)
# Generic build system: edp <project> <command> [options]

# --- Configuration ---
EDP_VM_HOST="${EDP_VM_HOST:-eifert-dev}"
EDP_VM_DIR_BASE="${EDP_VM_DIR_BASE:-C:\\Users\\Admin\\Entwicklung}"
EDP_SMB_SHARE="${EDP_SMB_SHARE:-\\\\192.168.122.1\\edp}"
EDP_SMB_USER="${EDP_SMB_USER:-tim}"
EDP_PROJECT_ROOT="${EDP_PROJECT_ROOT:-$HOME/Develop/EDP}"
EDP_VM_NAME="${EDP_VM_NAME:-EifertSystem_Development}"

# Fixed VM-side tool paths
EDP_RSVARS='C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat'
EDP_MSBUILD='C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe'

# --- Internal helpers ---

# Run a command on the VM with SMB share connected (single SSH session)
_edp_vm_cmd() {
  ssh "$EDP_VM_HOST" "net use ${EDP_SMB_SHARE} PoseidonEDP /user:${EDP_SMB_USER} 2>nul & $*" | iconv -f CP850 -t UTF-8 2>/dev/null
}

# Read a value from a project's compile.config
_edp_config() {
  local project="$1" key="$2"
  local file="$EDP_PROJECT_ROOT/$project/compile.config"
  grep "^${key}=" "$file" 2>/dev/null | cut -d= -f2
}

# VM-side project directory path
_edp_vm_dir() {
  printf '%s\\%s\n' "$EDP_VM_DIR_BASE" "$1"
}

# --- Main function ---

edp() {
  local project="${1:-}"
  local command="${2:-}"

  if [[ -z "$project" || -z "$command" ]]; then
    echo "Usage: edp <project> <command> [options]"
    echo ""
    echo "Commands:"
    echo "  compile [-b] [-p:Win32|Win64] [-cfg:Debug|Release]"
    echo "  start       Start service"
    echo "  stop        Stop service"
    echo "  status      Query service status"
    echo "  log [filter] [-l=LEVEL]  Stream live log"
    echo "  compilelog  Show compile log"
    return 1
  fi

  shift 2

  local vm_dir
  vm_dir="$(_edp_vm_dir "$project")"

  case "$command" in
    compile)
      _edp_compile "$project" "$vm_dir" "$@"
      ;;
    start)
      local svc
      svc="$(_edp_config "$project" SERVICE_NAME)"
      if [[ -z "$svc" ]]; then
        echo "edp: no SERVICE_NAME in compile.config for $project" >&2
        return 1
      fi
      _edp_vm_cmd "net start $svc"
      ;;
    stop)
      local svc
      svc="$(_edp_config "$project" SERVICE_NAME)"
      if [[ -z "$svc" ]]; then
        echo "edp: no SERVICE_NAME in compile.config for $project" >&2
        return 1
      fi
      _edp_vm_cmd "net stop $svc"
      ;;
    status)
      local svc
      svc="$(_edp_config "$project" SERVICE_NAME)"
      if [[ -z "$svc" ]]; then
        echo "edp: no SERVICE_NAME in compile.config for $project" >&2
        return 1
      fi
      _edp_vm_cmd "sc query $svc"
      ;;
    log)
      _edp_log "$project" "$vm_dir" "$@"
      ;;
    compilelog)
      LC_ALL=C ssh "$EDP_VM_HOST" "net use ${EDP_SMB_SHARE} PoseidonEDP /user:${EDP_SMB_USER} 2>nul & powershell -NoProfile -Command \"Get-Content -Path '${vm_dir}\\compile.log' -Tail 200 -Wait\"" \
        | LC_ALL=C awk 'NR==1 { system("printf \"\\033c\"") } { sub(/\r$/,""); print; fflush() }'
      ;;
    *)
      echo "edp: unknown command '$command'" >&2
      echo "Commands: compile, start, stop, status, log, compilelog" >&2
      return 1
      ;;
  esac
}

# --- Compile ---

_edp_compile() {
  local project="$1" vm_dir="$2"
  shift 2

  # Read defaults from compile.config
  local proj_name plat cfg svc deploy_mode target
  proj_name="$(_edp_config "$project" PROJECT_NAME)"
  plat="$(_edp_config "$project" PLATFORM)"
  cfg="$(_edp_config "$project" CONFIG)"
  svc="$(_edp_config "$project" SERVICE_NAME)"
  deploy_mode="$(_edp_config "$project" DEPLOY_MODE)"
  deploy_mode="${deploy_mode:-none}"
  target="Make"

  # Parse CLI options (override defaults)
  while (($#)); do
    case "$1" in
      -b)         target="Build" ;;
      -p:*)       plat="${1#-p:}" ;;
      -cfg:*)     cfg="${1#-cfg:}" ;;
      *)          echo "edp compile: unknown option '$1'" >&2; return 1 ;;
    esac
    shift
  done

  if [[ -z "$proj_name" ]]; then
    echo "edp: no PROJECT_NAME in compile.config for $project" >&2
    return 1
  fi

  # Defaults
  plat="${plat:-Win64}"
  cfg="${cfg:-Release}"

  echo "=== Kompiliere $project ==="
  echo "  Projekt:   $proj_name"
  echo "  Target:    $target"
  echo "  Plattform: $plat"
  echo "  Config:    $cfg"
  echo "  Deploy:    $deploy_mode"
  echo ""

  # Stop service before compile (mirror + exe modes, if SERVICE_NAME set)
  if [[ "$deploy_mode" != "none" && -n "$svc" ]]; then
    echo "Stoppe Dienst $svc..."
    _edp_vm_cmd "net stop $svc 2>nul"
    local i
    for i in {1..20}; do
      local state
      state="$(ssh "$EDP_VM_HOST" "sc query $svc" 2>/dev/null | iconv -f CP850 -t UTF-8 2>/dev/null)"
      if echo "$state" | grep -q "STOPPED"; then
        break
      fi
      echo "  Warte auf Stoppen..."
      sleep 2
    done
  fi

  # Compile via SSH
  echo "Kompiliere..."
  local compile_cmd="call \"${EDP_RSVARS}\" && cd /d ${vm_dir} && \"${EDP_MSBUILD}\" ${proj_name} /t:${target} /p:config=${cfg} /p:platform=${plat}"
  _edp_vm_cmd "$compile_cmd" > /tmp/edp_compile_$$.log 2>&1
  local rc=$?

  if [[ $rc -ne 0 ]]; then
    echo ""
    echo "FEHLER beim Kompilieren! Output:" >&2
    cat /tmp/edp_compile_$$.log >&2
    rm -f /tmp/edp_compile_$$.log
    return $rc
  fi

  # Check for "Build succeeded" or "0 Error(s)" in output
  if ! grep -qi "0 Error(s)\|Build succeeded\|0 Fehler\|Buildvorgang.*erfolgreich" /tmp/edp_compile_$$.log; then
    echo ""
    echo "FEHLER: Build nicht erfolgreich. Output:" >&2
    cat /tmp/edp_compile_$$.log >&2
    rm -f /tmp/edp_compile_$$.log
    return 1
  fi

  echo "Kompilierung erfolgreich."
  rm -f /tmp/edp_compile_$$.log

  # Deploy based on DEPLOY_MODE
  case "$deploy_mode" in
    mirror)
      local deploy_dir="C:\\${project}"
      printf 'Kopiere nach %s...\n' "$deploy_dir"
      _edp_vm_cmd "robocopy \"${vm_dir}\" \"${deploy_dir}\" /mir /xd .git src Win64 setup tools wiki .claude /xf *.dpr *.dproj *.dproj.local *.res *.cmds *.delphilsp.json *.ico compile.config compile.log jsconfig.json .gitignore .prettierrc schema.sql sign.bat setup.iss CLAUDE.md README.md /njh /njs /ndl /nc /ns /np /nfl >nul"
      ;;
    exe)
      local exe_name="${proj_name%.dproj}.exe"
      printf 'Kopiere %s nach C:\\edpserver...\n' "$exe_name"
      _edp_vm_cmd "copy /y \"${vm_dir}\\${exe_name}\" \"C:\\edpserver\\${exe_name}\" >nul"
      ;;
    none)
      echo "Kein Deploy (DEPLOY_MODE=none)."
      ;;
  esac

  # Start service after deploy (mirror + exe modes, if SERVICE_NAME set)
  if [[ "$deploy_mode" != "none" && -n "$svc" ]]; then
    echo "Starte Dienst $svc..."
    _edp_vm_cmd "net start $svc"
  fi

  echo ""
  echo "=== Fertig ==="
}

# --- Log streaming ---

_edp_log() {
  local project="$1"
  shift; shift  # skip vm_dir (unused, kept for call compat)

  local deploy_mode
  deploy_mode="$(_edp_config "$project" DEPLOY_MODE)"
  deploy_mode="${deploy_mode:-none}"

  local logpath
  case "$deploy_mode" in
    mirror) logpath="C:\\${project}\\${project}.log" ;;
    exe)    logpath="C:\\edpserver\\Logfiles\\${project}.log" ;;
    none)
      echo "edp log: kein Log-Streaming für DEPLOY_MODE=none" >&2
      return 1
      ;;
  esac

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

  LC_ALL=C ssh "$EDP_VM_HOST" "net use ${EDP_SMB_SHARE} PoseidonEDP /user:${EDP_SMB_USER} 2>nul & powershell -NoProfile -Command \"Get-Content -Path '${logpath}' -Tail 200 -Wait\"" \
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
}

# --- Sync (legacy fallback) ---

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
    --exclude '*.exe' \
    --exclude '*.log' \
    --exclude 'html/' \
    --exclude 'Win64/' \
    --exclude 'Logs/' \
    --exclude 'rechte/' \
    --exclude 'keys/' \
    --exclude 'setup/' \
    --no-perms --no-owner --no-group --chmod=ugo=rwX \
    ./ "${EDP_VM_HOST}:/cygdrive/c/Users/Admin/Entwicklung/${dir}/" >"$changesfile"

  if [[ -s "$changesfile" ]]; then
    tail -n +2 "$changesfile"
  else
    echo "rsync: no changes"
  fi
  rm -f "$changesfile"
}

# --- VM lifecycle ---

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

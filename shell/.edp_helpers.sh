# Helper functions for EDP development (bash + zsh compatible)
# Generic build system: edp <project> <command> [options]

# --- Configuration ---
EDP_VM_HOST="${EDP_VM_HOST:-eifert-dev}"
EDP_VM_DIR_BASE='C:\EDP'
EDP_PROJECT_ROOT="${EDP_PROJECT_ROOT:-$HOME/Develop/EDP}"
EDP_VM_NAME="${EDP_VM_NAME:-EifertSystem_Development}"
EDP_SERVICES=(edpwebservice EDPSrv)

# Fixed VM-side tool paths
EDP_RSVARS='C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat'
EDP_MSBUILD='C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe'

# --- Internal helpers ---

# Run a command on a host via SSH
_edp_vm_cmd() {
  local host="$1"
  shift
  ssh "$host" "$*" | iconv -f CP850 -t UTF-8 2>/dev/null
}

# Auto-detect .dproj file in project directory
_edp_detect_dproj() {
  local project="$1"
  local dir="$EDP_PROJECT_ROOT/$project"
  local files=("$dir"/*.dproj)
  # Use ${files[@]:0:1} for bash/zsh compat (zsh is 1-indexed)
  local first="${files[1]:-${files[0]}}"
  if [[ ${#files[@]} -eq 1 && -f "$first" ]]; then
    basename "$first"
  else
    echo "edp: .dproj nicht eindeutig in $dir (${#files[@]} gefunden)" >&2
    return 1
  fi
}

# Target directory on VM: C:\EDP\<project>
_edp_target_dir() {
  local project="$1"
  printf 'C:\\EDP\\%s' "$project"
}

# Push files via tar-over-SSH
_edp_push() {
  local project_dir="$1" target_host="$2" target_dir="$3"
  shift 3
  # $@ = additional --exclude= arguments from caller

  ssh "$target_host" "if not exist \"${target_dir}\" mkdir \"${target_dir}\"" 2>/dev/null

  tar cf - -C "$project_dir" \
    --exclude='.git' \
    --exclude='.claude' \
    --exclude='__history' \
    --exclude='__recovery' \
    --exclude='Win64' \
    --exclude='*.log' \
    --exclude='*.ini' \
    "$@" \
    . | ssh "$target_host" "tar xf - --options=hdrcharset=UTF-8 -C \"${target_dir}\""
}

# Stop a Windows service and wait for STOPPED state
_edp_svc_stop() {
  local host="$1" svc="$2"
  echo "Stoppe Dienst $svc..."
  ssh "$host" "net stop $svc 2>nul" 2>/dev/null | iconv -f CP850 -t UTF-8 2>/dev/null
  local i state
  for i in {1..20}; do
    state="$(ssh "$host" "sc query $svc" 2>/dev/null | iconv -f CP850 -t UTF-8 2>/dev/null)"
    if [[ -z "$state" ]] || echo "$state" | grep -q "STOPPED"; then break; fi
    echo "  Warte auf Stoppen..."
    sleep 2
  done
}

# Start a Windows service
_edp_svc_start() {
  local host="$1" svc="$2"
  echo "Starte Dienst $svc..."
  ssh "$host" "net start $svc" 2>/dev/null | iconv -f CP850 -t UTF-8 2>/dev/null
}

# Stop all EDP services
_edp_svc_stop_all() {
  local host="$1"
  local svc
  for svc in "${EDP_SERVICES[@]}"; do
    _edp_svc_stop "$host" "$svc"
  done
}

# Start all EDP services
_edp_svc_start_all() {
  local host="$1"
  local svc
  for svc in "${EDP_SERVICES[@]}"; do
    _edp_svc_start "$host" "$svc"
  done
}

# --- Main function ---

edp() {
  local arg1="${1:-}"

  if [[ -z "$arg1" ]]; then
    echo "Usage: edp <project> <command> [options]"
    echo "       edp start|stop|status <service> [host]"
    echo ""
    echo "Project commands:"
    echo "  deploy [host] [--with-exe]    Push files to host"
    echo "  compile [host] [-b] [-p:...] [-cfg:...]  Deploy + Build + fetch exe"
    echo "  log [filter] [-l=LEVEL]       Stream live log"
    echo "  compilelog                    Show compile log"
    echo ""
    echo "Service commands:"
    echo "  start <service> [host]   Start a Windows service"
    echo "  stop <service> [host]    Stop a Windows service"
    echo "  status <service> [host]  Query service status"
    return 1
  fi

  # Service mode: edp start|stop|status <service> [host]
  case "$arg1" in
    start|stop|status)
      local svc_cmd="$arg1"
      local svc="${2:-}"
      if [[ -z "$svc" ]]; then
        echo "edp $svc_cmd: service name required" >&2
        return 1
      fi
      local host="${3:-$EDP_VM_HOST}"
      case "$svc_cmd" in
        start)  _edp_svc_start "$host" "$svc" ;;
        stop)   _edp_svc_stop "$host" "$svc" ;;
        status) _edp_vm_cmd "$host" "sc query $svc" ;;
      esac
      return
      ;;
  esac

  # Project mode: edp <project> <command> [options]
  local project="$arg1"
  local command="${2:-}"

  if [[ -z "$command" ]]; then
    echo "edp: command required (deploy, compile, log, compilelog)" >&2
    return 1
  fi

  shift 2

  case "$command" in
    compile)
      _edp_compile "$project" "$@"
      ;;
    deploy)
      _edp_deploy "$project" "$@"
      ;;
    log)
      _edp_log "$project" "$@"
      ;;
    compilelog)
      local target_dir
      target_dir="$(_edp_target_dir "$project")"
      LC_ALL=C ssh "$EDP_VM_HOST" "powershell -NoProfile -Command \"Get-Content -Path '${target_dir}\\compile.log' -Tail 200 -Wait\"" \
        | LC_ALL=C awk 'NR==1 { system("printf \"\\033c\"") } { sub(/\r$/,""); print; fflush() }'
      ;;
    *)
      echo "edp: unknown command '$command'" >&2
      echo "Commands: compile, deploy, log, compilelog" >&2
      echo "Service commands: edp start|stop|status <service> [host]" >&2
      return 1
      ;;
  esac
}

# --- Deploy ---

_edp_deploy() {
  local project="$1"
  shift

  local target_host="$EDP_VM_HOST"
  local with_exe=false
  local args=()

  while (($#)); do
    case "$1" in
      --with-exe) with_exe=true ;;
      *)          args+=("$1") ;;
    esac
    shift
  done

  # First positional arg (if any) is the host
  if [[ ${#args[@]} -gt 0 ]]; then
    target_host="${args[0]}"
  fi

  local target_dir
  target_dir="$(_edp_target_dir "$project")"

  echo "=== Deploy $project → $target_host ==="
  printf '  Ziel: %s\n' "$target_dir"
  if $with_exe; then
    echo "  Modus: mit EXE (Services werden gestoppt/gestartet)"
  else
    echo "  Modus: ohne EXE (kein Service-Stop)"
  fi
  echo ""

  # With --with-exe: stop all services first
  if $with_exe; then
    _edp_svc_stop_all "$target_host"
  fi

  # Push files
  echo "Übertrage Dateien..."
  if $with_exe; then
    _edp_push "$EDP_PROJECT_ROOT/$project" "$target_host" "$target_dir"
  else
    _edp_push "$EDP_PROJECT_ROOT/$project" "$target_host" "$target_dir" --exclude='*.exe' --exclude='*.dll'
  fi
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "FEHLER beim Übertragen! (exit code: $rc)" >&2
    return $rc
  fi

  # With --with-exe: start all services
  if $with_exe; then
    _edp_svc_start_all "$target_host"
  fi

  echo ""
  echo "=== Deploy fertig ==="
}

# --- Compile ---

_edp_compile() {
  local project="$1"
  shift

  local target_host="$EDP_VM_HOST"
  local plat="Win64"
  local cfg="Release"
  local target="Make"
  local args=()

  while (($#)); do
    case "$1" in
      -b)     target="Build" ;;
      -p:*)   plat="${1#-p:}" ;;
      -cfg:*) cfg="${1#-cfg:}" ;;
      *)      args+=("$1") ;;
    esac
    shift
  done

  # First positional arg (if any) is the host
  if [[ ${#args[@]} -gt 0 ]]; then
    target_host="${args[0]}"
  fi

  # Auto-detect .dproj
  local proj_name
  proj_name="$(_edp_detect_dproj "$project")" || return 1

  local target_dir
  target_dir="$(_edp_target_dir "$project")"
  local exe_name="${proj_name%.dproj}.exe"

  echo "=== Kompiliere $project auf $target_host ==="
  echo "  Projekt:   $proj_name"
  echo "  Target:    $target"
  echo "  Plattform: $plat"
  echo "  Config:    $cfg"
  echo ""

  # Step 1: Stop all services
  _edp_svc_stop_all "$target_host"

  # Step 2: Deploy files (without EXE)
  echo "Übertrage Dateien..."
  _edp_push "$EDP_PROJECT_ROOT/$project" "$target_host" "$target_dir" --exclude='*.exe'
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "FEHLER beim Übertragen! (exit code: $rc)" >&2
    _edp_svc_start_all "$target_host"
    return $rc
  fi

  # Step 3: MSBuild via SSH
  echo "Kompiliere..."
  local compile_cmd="call \"${EDP_RSVARS}\" && cd /d ${target_dir} && \"${EDP_MSBUILD}\" ${proj_name} /t:${target} /p:config=${cfg} /p:platform=${plat}"
  ssh "$target_host" "$compile_cmd" > /tmp/edp_compile_$$.log 2>&1
  rc=$?

  if [[ $rc -ne 0 ]]; then
    echo ""
    echo "FEHLER beim Kompilieren! Output:" >&2
    cat /tmp/edp_compile_$$.log >&2
    rm -f /tmp/edp_compile_$$.log
    _edp_svc_start_all "$target_host"
    return $rc
  fi

  if ! grep -qi "0 Error(s)\|Build succeeded\|0 Fehler\|Buildvorgang.*erfolgreich" /tmp/edp_compile_$$.log; then
    echo ""
    echo "FEHLER: Build nicht erfolgreich. Output:" >&2
    cat /tmp/edp_compile_$$.log >&2
    rm -f /tmp/edp_compile_$$.log
    _edp_svc_start_all "$target_host"
    return 1
  fi

  echo "Kompilierung erfolgreich."
  rm -f /tmp/edp_compile_$$.log

  # Step 4: Fetch exe back to Linux
  local remote_dir="C:/EDP/$project"
  echo "Hole ${exe_name} zurück..."
  scp "$target_host:${remote_dir}/${exe_name}" \
    "$EDP_PROJECT_ROOT/$project/${exe_name}"

  # Step 5: Start all services
  _edp_svc_start_all "$target_host"

  echo ""
  echo "=== Fertig ==="
}

# --- Log streaming ---

_edp_log() {
  local project="$1"
  shift

  local target_dir
  target_dir="$(_edp_target_dir "$project")"
  local logpath="${target_dir}\\${project}.log"

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

  LC_ALL=C ssh "$EDP_VM_HOST" "powershell -NoProfile -Command \"Get-Content -Path '${logpath}' -Tail 200 -Wait\"" \
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

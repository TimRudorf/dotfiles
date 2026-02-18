# Helper functions for EDP development (bash + zsh compatible)
# Generic build system: edp <project> <command> [options]

# --- Configuration ---
EDP_VM_HOST="${EDP_VM_HOST:-eifert-dev}"
EDP_VM_DIR_BASE='C:\EDP'
EDP_PROJECT_ROOT="${EDP_PROJECT_ROOT:-$HOME/Develop/EDP}"
EDP_VM_NAME="${EDP_VM_NAME:-EifertSystem_Development}"

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

# Read a value from a project's compile.config
_edp_config() {
  local project="$1" key="$2"
  local file="$EDP_PROJECT_ROOT/$project/compile.config"
  grep "^${key}=" "$file" 2>/dev/null | cut -d= -f2
}

# Target directory on VM: C:\EDP\<TARGET_DIR or project>
_edp_target_dir() {
  local project="$1"
  local target_dir
  target_dir="$(_edp_config "$project" TARGET_DIR)"
  printf 'C:\\EDP\\%s' "${target_dir:-$project}"
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

# --- Main function ---

edp() {
  local project="${1:-}"
  local command="${2:-}"

  if [[ -z "$project" || -z "$command" ]]; then
    echo "Usage: edp <project> <command> [options]"
    echo ""
    echo "Commands:"
    echo "  deploy [host]    Push files to host (default: \$EDP_VM_HOST)"
    echo "  compile [host]   Build on host + fetch exe (default: \$EDP_VM_HOST)"
    echo "    [-b] [-p:Win32|Win64] [-cfg:Debug|Release]"
    echo "  start [host]     Start service"
    echo "  stop [host]      Stop service"
    echo "  status [host]    Query service status"
    echo "  log [filter] [-l=LEVEL]  Stream live log"
    echo "  compilelog       Show compile log"
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
    start)
      local svc host
      svc="$(_edp_config "$project" SERVICE_NAME)"
      if [[ -z "$svc" ]]; then
        echo "edp: no SERVICE_NAME in compile.config for $project" >&2
        return 1
      fi
      host="${1:-$EDP_VM_HOST}"
      _edp_vm_cmd "$host" "net start $svc"
      ;;
    stop)
      local svc host
      svc="$(_edp_config "$project" SERVICE_NAME)"
      if [[ -z "$svc" ]]; then
        echo "edp: no SERVICE_NAME in compile.config for $project" >&2
        return 1
      fi
      host="${1:-$EDP_VM_HOST}"
      _edp_vm_cmd "$host" "net stop $svc"
      ;;
    status)
      local svc host
      svc="$(_edp_config "$project" SERVICE_NAME)"
      if [[ -z "$svc" ]]; then
        echo "edp: no SERVICE_NAME in compile.config for $project" >&2
        return 1
      fi
      host="${1:-$EDP_VM_HOST}"
      _edp_vm_cmd "$host" "sc query $svc"
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
      echo "Commands: compile, deploy, start, stop, status, log, compilelog" >&2
      return 1
      ;;
  esac
}

# --- Deploy ---

_edp_deploy() {
  local project="$1"
  shift
  local target_host="${1:-$EDP_VM_HOST}"

  local target_dir svc
  target_dir="$(_edp_target_dir "$project")"
  svc="$(_edp_config "$project" SERVICE_NAME)"

  echo "=== Deploy $project → $target_host ==="
  printf '  Ziel: %s\n' "$target_dir"
  [[ -n "$svc" ]] && echo "  Service: $svc"
  echo ""

  # Stop service if configured
  if [[ -n "$svc" ]]; then
    _edp_svc_stop "$target_host" "$svc"
  fi

  # Push files
  echo "Übertrage Dateien..."
  _edp_push "$EDP_PROJECT_ROOT/$project" "$target_host" "$target_dir"
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "FEHLER beim Übertragen! (exit code: $rc)" >&2
    return $rc
  fi

  # Start service if configured
  if [[ -n "$svc" ]]; then
    _edp_svc_start "$target_host" "$svc"
  fi

  echo ""
  echo "=== Deploy fertig ==="
}

# --- Compile ---

_edp_compile() {
  local project="$1"
  shift
  local target_host="${1:-$EDP_VM_HOST}"
  shift 2>/dev/null || true

  local proj_name plat cfg svc target_dir
  proj_name="$(_edp_config "$project" PROJECT_NAME)"
  plat="$(_edp_config "$project" PLATFORM)"
  cfg="$(_edp_config "$project" CONFIG)"
  svc="$(_edp_config "$project" SERVICE_NAME)"
  target_dir="$(_edp_target_dir "$project")"

  # Parse optional CLI flags (after hostname)
  local target="Make"
  while (($#)); do
    case "$1" in
      -b)     target="Build" ;;
      -p:*)   plat="${1#-p:}" ;;
      -cfg:*) cfg="${1#-cfg:}" ;;
      *)      echo "edp compile: unknown option '$1'" >&2; return 1 ;;
    esac
    shift
  done

  plat="${plat:-Win64}"
  cfg="${cfg:-Release}"

  if [[ -z "$proj_name" ]]; then
    echo "edp: no PROJECT_NAME in compile.config for $project" >&2
    return 1
  fi

  local exe_name="${proj_name%.dproj}.exe"

  echo "=== Kompiliere $project auf $target_host ==="
  echo "  Projekt:   $proj_name"
  echo "  Target:    $target"
  echo "  Plattform: $plat"
  echo "  Config:    $cfg"
  echo ""

  # Stop service before compile
  if [[ -n "$svc" ]]; then
    _edp_svc_stop "$target_host" "$svc"
  fi

  # MSBuild via SSH
  echo "Kompiliere..."
  local compile_cmd="call \"${EDP_RSVARS}\" && cd /d ${target_dir} && \"${EDP_MSBUILD}\" ${proj_name} /t:${target} /p:config=${cfg} /p:platform=${plat}"
  ssh "$target_host" "$compile_cmd" > /tmp/edp_compile_$$.log 2>&1
  local rc=$?

  if [[ $rc -ne 0 ]]; then
    echo ""
    echo "FEHLER beim Kompilieren! Output:" >&2
    cat /tmp/edp_compile_$$.log >&2
    rm -f /tmp/edp_compile_$$.log
    return $rc
  fi

  if ! grep -qi "0 Error(s)\|Build succeeded\|0 Fehler\|Buildvorgang.*erfolgreich" /tmp/edp_compile_$$.log; then
    echo ""
    echo "FEHLER: Build nicht erfolgreich. Output:" >&2
    cat /tmp/edp_compile_$$.log >&2
    rm -f /tmp/edp_compile_$$.log
    return 1
  fi

  echo "Kompilierung erfolgreich."
  rm -f /tmp/edp_compile_$$.log

  # Fetch exe back to Linux
  local remote_dir="C:/EDP/${target_dir##*\\}"
  echo "Hole ${exe_name} zurück..."
  scp "$target_host:${remote_dir}/${exe_name}" \
    "$EDP_PROJECT_ROOT/$project/${exe_name}"

  # Start service after compile
  if [[ -n "$svc" ]]; then
    _edp_svc_start "$target_host" "$svc"
  fi

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

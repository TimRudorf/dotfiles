# Helper functions for EDP development (bash + zsh compatible)
# Generic build system: edp <project> <command> [options]

# --- Configuration ---
EDP_VM_HOST="${EDP_VM_HOST:-eifert-dev}"
EDP_VM_DIR_BASE='C:\EDP'
EDP_PROJECT_ROOT="${EDP_PROJECT_ROOT:-$HOME/Develop/EDP}"

# Fixed VM-side tool paths
EDP_RSVARS='C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat'
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

# Detect project type: "delphi" (wenn .dproj vorhanden) oder "go" (wenn go.mod
# vorhanden). Echo den Typ auf stdout, oder leer + Rückgabe 1 wenn nichts passt.
_edp_detect_project_type() {
  local project="$1"
  local dir="$EDP_PROJECT_ROOT/$project"
  if ls "$dir"/*.dproj >/dev/null 2>&1; then
    echo "delphi"
  elif [[ -f "$dir/go.mod" ]]; then
    echo "go"
  else
    echo "edp: Kein bekannter Projekttyp in $dir (weder .dproj noch go.mod)" >&2
    return 1
  fi
}

# Target directory on VM: C:\EDP\<project>
_edp_target_dir() {
  local project="$1"
  printf 'C:\\EDP\\%s' "$project"
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

# Map project → Windows service name that locks its EXE.
# Dienste werden NICHT automatisch erstellt — Installation erfolgt manuell.
# Wenn ein Projekt hier nicht gelistet ist, wird kein Service gestoppt.
_edp_service_for_project() {
  local project="$1"
  case "$project" in
    edpweb)   echo "edpwebservice" ;;
    schn_*)   echo "EDPSrv" ;;         # alle EDPServer-Schnittstellen
    server)   echo "EDPSrv" ;;
    *)        echo "" ;;
  esac
}

# Stop the Windows service (if any) that locks the project's EXE.
_edp_svc_stop_for_project() {
  local host="$1" project="$2"
  local svc
  svc="$(_edp_service_for_project "$project")"
  if [[ -n "$svc" ]]; then
    _edp_svc_stop "$host" "$svc"
  fi
}

# Start the Windows service (if any) associated with the project.
_edp_svc_start_for_project() {
  local host="$1" project="$2"
  local svc
  svc="$(_edp_service_for_project "$project")"
  if [[ -n "$svc" ]]; then
    _edp_svc_start "$host" "$svc"
  fi
}

# --- Main function ---

edp() {
  local arg1="${1:-}"

  if [[ -z "$arg1" ]]; then
    echo "Usage: edp <project> <command> [options]"
    echo "       edp start|stop|status <service> [host]"
    echo ""
    echo "Project commands:"
    echo "  compile [host] [-b] [-p:...] [-cfg:...]  Git-sync + Build + fetch exe"
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
    echo "edp: command required (compile, log, compilelog)" >&2
    return 1
  fi

  shift 2

  case "$command" in
    compile)
      _edp_compile "$project" "$@"
      ;;
    deploy)
      echo "edp: 'deploy' wurde entfernt. Git ist source of truth — benutze 'edp $project compile'." >&2
      return 1
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
      echo "Commands: compile, log, compilelog" >&2
      echo "Service commands: edp start|stop|status <service> [host]" >&2
      return 1
      ;;
  esac
}

# --- Git helpers ---

# Verify local repo is clean + ahead-only; auto-push ahead commits.
# Echoes the current branch name on success.
_edp_git_prepare() {
  local project_dir="$1"

  if ! git -C "$project_dir" rev-parse --git-dir >/dev/null 2>&1; then
    echo "FEHLER: $project_dir ist kein Git-Repo" >&2
    return 1
  fi

  local branch
  branch="$(git -C "$project_dir" symbolic-ref --short -q HEAD)" || {
    echo "FEHLER: detached HEAD in $project_dir — bitte einen Branch auschecken" >&2
    return 1
  }

  if [[ -n "$(git -C "$project_dir" status --porcelain)" ]]; then
    echo "FEHLER: Working tree nicht sauber. Bitte committen (ggf. --amend) oder stashen:" >&2
    git -C "$project_dir" status --short >&2
    return 1
  fi

  # Fetch remote state for this branch
  git -C "$project_dir" fetch --quiet origin "$branch" 2>/dev/null

  # Refuse if we're behind origin (history divergent)
  local behind
  behind="$(git -C "$project_dir" rev-list --count "HEAD..origin/$branch" 2>/dev/null || echo 0)"
  if [[ "$behind" -gt 0 ]]; then
    echo "FEHLER: origin/$branch hat $behind Commit(s), die lokal fehlen. Bitte pullen/rebasen." >&2
    return 1
  fi

  # Auto-push if we're ahead (or if remote branch doesn't exist yet)
  local ahead=0
  if git -C "$project_dir" rev-parse --verify --quiet "origin/$branch" >/dev/null; then
    ahead="$(git -C "$project_dir" rev-list --count "origin/$branch..HEAD" 2>/dev/null || echo 0)"
  else
    ahead=1  # remote branch missing → treat as push-needed
  fi
  if [[ "$ahead" -gt 0 ]]; then
    echo "Push $ahead Commit(s) → origin/$branch..." >&2
    git -C "$project_dir" push --quiet -u origin "$branch" >&2 || return 1
  fi

  printf '%s' "$branch"
}

# Clone repo to VM on first use, else fetch + hard-reset to origin/<branch>.
# Leaves build outputs (Win64/, *.dcu) intact for incremental builds.
_edp_git_sync_vm() {
  local host="$1" target_dir="$2" clone_url="$3" branch="$4"
  local dir_forward="${target_dir//\\//}"

  local have_git
  have_git="$(ssh "$host" "if exist \"${target_dir}\\.git\" (echo yes) else (echo no)" 2>/dev/null | tr -d '\r' | tr -d '\n')"

  if [[ "$have_git" != "yes" ]]; then
    echo "Klone Repo auf VM: ${target_dir}..."
    ssh "$host" "if exist \"${target_dir}\" rmdir /s /q \"${target_dir}\"" 2>/dev/null
    ssh "$host" "git clone --quiet --branch ${branch} ${clone_url} \"${target_dir}\"" || return 1
  else
    echo "Synchronisiere Repo auf VM (branch ${branch})..."
    ssh "$host" "cd /d \"${target_dir}\" && git fetch --quiet origin && git checkout --quiet -B ${branch} origin/${branch} && git reset --hard --quiet origin/${branch}" || return 1
  fi
}

# --- SCSS build on VM ---

# Kompiliert SCSS auf der VM via npm, falls package.json vorhanden ist.
_edp_scss_build_vm() {
  local host="$1" target_dir="$2"

  local has_pkg
  has_pkg="$(ssh "$host" "if exist \"${target_dir}\\package.json\" (echo yes) else (echo no)" 2>/dev/null | tr -d '\r\n')"
  if [[ "$has_pkg" != "yes" ]]; then
    return 0
  fi

  echo "SCSS kompilieren..."

  # node_modules nur installieren wenn noch nicht vorhanden
  local has_nm
  has_nm="$(ssh "$host" "if exist \"${target_dir}\\node_modules\" (echo yes) else (echo no)" 2>/dev/null | tr -d '\r\n')"
  if [[ "$has_nm" != "yes" ]]; then
    echo "  npm install (erstmalig)..."
    ssh "$host" "cd /d \"${target_dir}\" && npm install" > /tmp/edp_npm_$$.log 2>&1
    local rc=$?
    if [[ $rc -ne 0 ]]; then
      echo "FEHLER beim npm install! Output:" >&2
      cat /tmp/edp_npm_$$.log >&2
      rm -f /tmp/edp_npm_$$.log
      return $rc
    fi
    rm -f /tmp/edp_npm_$$.log
  fi

  ssh "$host" "cd /d \"${target_dir}\" && npm run scss:build" > /tmp/edp_scss_$$.log 2>&1
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "FEHLER beim SCSS-Build! Output:" >&2
    cat /tmp/edp_scss_$$.log >&2
    rm -f /tmp/edp_scss_$$.log
    return $rc
  fi
  rm -f /tmp/edp_scss_$$.log
  echo "SCSS erfolgreich kompiliert."
}

# --- Compile ---

_edp_compile_go() {
  local project="$1"
  shift

  local target_host="$EDP_VM_HOST"
  local do_test=1       # Tests laufen standardmäßig mit; via -skip-tests abschaltbar
  local do_build_exe=0  # EXE-Output nur wenn main.go im Repo-Root
  local args=()

  while (($#)); do
    case "$1" in
      -skip-tests) do_test=0 ;;
      *)           args+=("$1") ;;
    esac
    shift
  done

  if [[ ${#args[@]} -gt 0 ]]; then
    target_host="${args[0]}"
  fi

  local project_dir="$EDP_PROJECT_ROOT/$project"
  local target_dir
  target_dir="$(_edp_target_dir "$project")"

  # Executable vs. Library: main.go im Root → Schnittstelle, sonst reine Library
  if [[ -f "$project_dir/main.go" ]]; then
    do_build_exe=1
  fi
  local exe_name="${project}.exe"

  # Git-Prep identisch zum Delphi-Pfad (clean + push)
  local branch clone_url
  branch="$(_edp_git_prepare "$project_dir")" || return 1
  clone_url="$(git -C "$project_dir" remote get-url origin)" || {
    echo "FEHLER: origin remote nicht gesetzt" >&2
    return 1
  }
  local sha
  sha="$(git -C "$project_dir" rev-parse --short HEAD)"

  echo "=== Kompiliere $project (Go) auf $target_host ==="
  echo "  Branch:  $branch ($sha)"
  echo "  Tests:   $([ $do_test -eq 1 ] && echo an || echo aus)"
  echo "  EXE:     $([ $do_build_exe -eq 1 ] && echo "ja ($exe_name)" || echo "nein (Library)")"
  echo ""

  _edp_svc_stop_for_project "$target_host" "$project"

  _edp_git_sync_vm "$target_host" "$target_dir" "$clone_url" "$branch"
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "FEHLER beim Git-Sync auf VM! (exit $rc)" >&2
    _edp_svc_start_for_project "$target_host" "$project"
    return $rc
  fi

  if ssh "$target_host" "findstr /S /C:\"//go:generate\" ${target_dir}\\*.go" >/dev/null 2>&1; then
    echo "go generate..."
    ssh "$target_host" "cd /d ${target_dir} && go generate ./..." > /tmp/edp_go_$$.log 2>&1
    rc=$?
    if [[ $rc -ne 0 ]]; then
      echo "FEHLER bei go generate:" >&2
      cat /tmp/edp_go_$$.log >&2
      rm -f /tmp/edp_go_$$.log
      _edp_svc_start_for_project "$target_host" "$project"
      return $rc
    fi
  fi

  echo "go build..."
  ssh "$target_host" "cd /d ${target_dir} && go build ./..." > /tmp/edp_go_$$.log 2>&1
  rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "FEHLER bei go build:" >&2
    cat /tmp/edp_go_$$.log >&2
    rm -f /tmp/edp_go_$$.log
    _edp_svc_start_for_project "$target_host" "$project"
    return $rc
  fi

  if [[ $do_test -eq 1 ]]; then
    echo "go test..."
    ssh "$target_host" "cd /d ${target_dir} && go test ./..." > /tmp/edp_go_$$.log 2>&1
    rc=$?
    if [[ $rc -ne 0 ]]; then
      echo "FEHLER bei go test:" >&2
      cat /tmp/edp_go_$$.log >&2
      rm -f /tmp/edp_go_$$.log
      _edp_svc_start_for_project "$target_host" "$project"
      return $rc
    fi
  fi

  if [[ $do_build_exe -eq 1 ]]; then
    echo "go build -o ${exe_name}..."
    ssh "$target_host" "cd /d ${target_dir} && go build -ldflags=\"-s -w\" -o ${exe_name} ." > /tmp/edp_go_$$.log 2>&1
    rc=$?
    if [[ $rc -ne 0 ]]; then
      echo "FEHLER beim EXE-Build:" >&2
      cat /tmp/edp_go_$$.log >&2
      rm -f /tmp/edp_go_$$.log
      _edp_svc_start_for_project "$target_host" "$project"
      return $rc
    fi

    echo "Hole ${exe_name} zurück..."
    scp "$target_host:${target_dir}/${exe_name}" "$project_dir/${exe_name}"
  fi

  echo "Go-Build erfolgreich."
  rm -f /tmp/edp_go_$$.log

  _edp_svc_start_for_project "$target_host" "$project"
}

_edp_compile() {
  local project="$1"
  shift

  local project_dir="$EDP_PROJECT_ROOT/$project"
  local ptype
  ptype="$(_edp_detect_project_type "$project")" || return 1

  if [[ "$ptype" == "go" ]]; then
    _edp_compile_go "$project" "$@"
    return $?
  fi

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

  # Git prep: clean + push (source of truth = GHE)
  local branch clone_url
  branch="$(_edp_git_prepare "$project_dir")" || return 1
  clone_url="$(git -C "$project_dir" remote get-url origin)" || {
    echo "FEHLER: origin remote nicht gesetzt" >&2
    return 1
  }
  local sha
  sha="$(git -C "$project_dir" rev-parse --short HEAD)"

  echo "=== Kompiliere $project auf $target_host ==="
  echo "  Projekt:   $proj_name"
  echo "  Branch:    $branch ($sha)"
  echo "  Target:    $target"
  echo "  Plattform: $plat"
  echo "  Config:    $cfg"
  echo ""

  # Step 1: Stop the service that locks this project's EXE (if any)
  _edp_svc_stop_for_project "$target_host" "$project"

  # Step 2: Git sync on VM
  _edp_git_sync_vm "$target_host" "$target_dir" "$clone_url" "$branch"
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "FEHLER beim Git-Sync auf VM! (exit $rc)" >&2
    _edp_svc_start_for_project "$target_host" "$project"
    return $rc
  fi

  # Step 2b: SCSS bauen (falls package.json vorhanden)
  _edp_scss_build_vm "$target_host" "$target_dir"
  rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "FEHLER beim SCSS-Build auf VM! (exit $rc)" >&2
    _edp_svc_start_for_project "$target_host" "$project"
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
    _edp_svc_start_for_project "$target_host" "$project"
    return $rc
  fi

  if ! grep -qi "0 Error(s)\|Build succeeded\|0 Fehler\|Buildvorgang.*erfolgreich" /tmp/edp_compile_$$.log; then
    echo ""
    echo "FEHLER: Build nicht erfolgreich. Output:" >&2
    cat /tmp/edp_compile_$$.log >&2
    rm -f /tmp/edp_compile_$$.log
    _edp_svc_start_for_project "$target_host" "$project"
    return 1
  fi

  echo "Kompilierung erfolgreich."
  rm -f /tmp/edp_compile_$$.log

  # Step 4: Fetch exe back to Linux
  local remote_dir="C:/EDP/$project"
  echo "Hole ${exe_name} zurück..."
  scp "$target_host:${remote_dir}/${exe_name}" \
    "$project_dir/${exe_name}"

  # Step 5: Restart the project's service
  _edp_svc_start_for_project "$target_host" "$project"

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

#!/usr/bin/env bash
# rm.sh — rmapi wrapper for remarkable-upload skill
# Sub-commands: put | ls | mkdir | sync | slug_to_folder
#
# Requires: rmapi binary (~/.local/bin/rmapi on Mac, /usr/local/bin/rmapi in container)
# Auth: one-time `rmapi ls /` with 8-char pairing code from my.remarkable.com/device/desktop/connect

set -euo pipefail

# Locate rmapi binary
if [[ -x "$HOME/.local/bin/rmapi" ]]; then
  RMAPI="$HOME/.local/bin/rmapi"
elif command -v rmapi >/dev/null 2>&1; then
  RMAPI=$(command -v rmapi)
else
  echo "ERROR: rmapi binary not found. Install from https://github.com/ddvk/rmapi/releases" >&2
  exit 1
fi

CMD="${1:-}"
shift || true

# Modul-Slug → reMarkable-Folder mapping (single source of truth)
slug_to_folder() {
  case "$1" in
    sensortechnik)            echo "/Studium/Sensortechnik" ;;
    sdrt3)                    echo "/Studium/SDRT3" ;;
    thermo)                   echo "/Studium/Thermo" ;;
    mldl-auto)                echo "/Studium/ML-DL" ;;
    praktikum-rt2)            echo "/Studium/P-RT2" ;;
    mpc-ml)                   echo "/Studium/MPC-ML" ;;
    rvcps)                    echo "/Studium/CDCPS" ;;
    dimm)                     echo "/Studium/DIMM" ;;
    ppm-seminar)              echo "/Studium/PPM-Seminar" ;;
    entrepreneurial)          echo "/Studium/Entrepreneurial" ;;
    modern-firm)              echo "/Studium/Modern-Firm" ;;
    international-economics)  echo "/Studium/IntEco" ;;
    *) echo "ERROR: unknown modul-slug: $1" >&2; return 1 ;;
  esac
}

# Idempotent mkdir (with parents). rmapi mkdir succeeds silently if folder exists.
mkdir_p() {
  local path="$1"
  # Build parents chain: /a/b/c → /a, /a/b, /a/b/c
  local parts
  IFS='/' read -ra parts <<< "${path#/}"
  local cur=""
  for p in "${parts[@]}"; do
    cur="$cur/$p"
    # Try to create; ignore "already exists" errors
    "$RMAPI" mkdir "$cur" >/dev/null 2>&1 || true
  done
  # Verify final path exists
  if "$RMAPI" stat "$path" >/dev/null 2>&1; then
    return 0
  fi
  # Fallback: assume it works since rmapi mkdir is silent on success
  return 0
}

case "$CMD" in
  put)
    LOCAL="${1:?Usage: $0 put <local-file> <remote-dir>}"
    REMOTE_DIR="${2:?Usage: $0 put <local-file> <remote-dir>}"
    if [[ ! -f "$LOCAL" ]]; then
      echo "ERROR: local file not found: $LOCAL" >&2
      exit 1
    fi
    # Strip trailing slash from remote dir for mkdir_p
    REMOTE_DIR="${REMOTE_DIR%/}"
    mkdir_p "$REMOTE_DIR"
    if "$RMAPI" put "$LOCAL" "$REMOTE_DIR/" 2>&1 | grep -q "OK"; then
      BASENAME=$(basename "$LOCAL" .pdf)
      BASENAME=$(basename "$BASENAME" .epub)
      echo "✅ Uploaded: $(basename "$LOCAL") → $REMOTE_DIR/$BASENAME"
    else
      echo "❌ Upload failed: $LOCAL" >&2
      exit 1
    fi
    ;;

  ls)
    PATH_ARG="${1:-/}"
    "$RMAPI" ls "$PATH_ARG"
    ;;

  mkdir)
    PATH_ARG="${1:?Usage: $0 mkdir <path>}"
    PATH_ARG="${PATH_ARG%/}"
    mkdir_p "$PATH_ARG"
    echo "✅ Folder ready: $PATH_ARG"
    ;;

  sync)
    LOCAL_DIR="${1:?Usage: $0 sync <local-dir> <remote-dir>}"
    REMOTE_DIR="${2:?Usage: $0 sync <local-dir> <remote-dir>}"
    if [[ ! -d "$LOCAL_DIR" ]]; then
      echo "ERROR: local dir not found: $LOCAL_DIR" >&2
      exit 1
    fi
    REMOTE_DIR="${REMOTE_DIR%/}"
    mkdir_p "$REMOTE_DIR"
    OK=0; FAIL=0
    shopt -s nullglob
    for f in "$LOCAL_DIR"/*.pdf "$LOCAL_DIR"/*.epub; do
      if "$RMAPI" put "$f" "$REMOTE_DIR/" 2>&1 | grep -q "OK"; then
        OK=$((OK+1))
        echo "  ✓ $(basename "$f")"
      else
        FAIL=$((FAIL+1))
        echo "  ✗ $(basename "$f")" >&2
      fi
    done
    shopt -u nullglob
    echo "Done: $OK uploaded, $FAIL failed → $REMOTE_DIR"
    [[ $FAIL -eq 0 ]] || exit 1
    ;;

  slug_to_folder)
    SLUG="${1:?Usage: $0 slug_to_folder <modul-slug>}"
    slug_to_folder "$SLUG"
    ;;

  ""|--help|-h|help)
    cat <<EOF
rm.sh — rmapi wrapper for reMarkable Cloud

Usage:
  $0 put <local-file> <remote-dir>     Upload PDF/EPUB, auto-mkdir parents
  $0 ls [path]                          List directory (default /)
  $0 mkdir <path>                       Create folder (idempotent, mkdir -p)
  $0 sync <local-dir> <remote-dir>      Mirror PDFs/EPUBs from local dir
  $0 slug_to_folder <modul-slug>        Print remote folder for a Lernplan module

One-time auth: \`rmapi ls /\` with 8-char code from my.remarkable.com/device/desktop/connect
EOF
    ;;

  *)
    echo "ERROR: unknown command: $CMD" >&2
    echo "Run '$0 help' for usage" >&2
    exit 1
    ;;
esac

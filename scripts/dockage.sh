#!/usr/bin/env bash
# dockage — Dockerfile management CLI
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for lib in "$DIR/libs/"*.sh; do
  . "$lib"
done

# ── Helpers ──────────────────────────────────
list_tools() {
  local root="$DIR/.."
  for dir in "$root"/*/; do
    local name
    name=$(basename "$dir")
    # Skip scripts/, tests/, hidden dirs
    [ "$name" = "scripts" ] && continue
    [ "$name" = "tests" ] && continue
    [[ "$name" == .* ]] && continue
    # Check if it has Dockerfiles
    ls "$dir"/Dockerfile* &>/dev/null || continue
    echo "$name"
  done | sort
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  build <tool> [version]    Build Docker image (with optional validation)
  validate <tool> [version] Validate Dockerfile conventions
  init <type> <name> <ver>  Scaffold new tool Dockerfile
  convert <tool> <version>  Convert Docker image to Singularity
  doctor                    Check dependencies and environment

Options:
  --help     Show help for a command
  --version  Show version
EOF
}

# ── Interactive TUI (whiptail) ────────────────
interactive_main_menu() {
  local choice
  choice=$(ui::menu "dockage" \
    "Build"   "Build a Docker image (with validation)" \
    "Validate" "Check a Dockerfile against repo conventions" \
    "Init"    "Scaffold a new tool Dockerfile" \
    "Convert" "Convert Docker image to Singularity" \
    "Doctor"  "Check dependencies and environment" \
    "Exit"    "Leave dockage") || exit 0

  case "$choice" in
    Build)    interactive_build ;;
    Validate) interactive_validate ;;
    Init)     interactive_init ;;
    Convert)  interactive_convert ;;
    Doctor)   interactive_doctor ;;
    Exit)     exit 0 ;;
  esac
}

# Pick a tool from the list using radiolist
pick_tool() {
  local title="${1:-Select Tool}"
  local tools
  tools=$(list_tools)
  [ -z "$tools" ] && { ui::msgbox "Error" "No tools found in dockage/"; return 1; }

  local items=()
  while IFS= read -r t; do
    # Check how many Dockerfiles this tool has
    local count
    count=$(ls "$DIR/../$t"/Dockerfile* 2>/dev/null | wc -l)
    items+=("$t" "$count Dockerfile(s)" "OFF")
  done <<< "$tools"

  ui::radiolist "$title" "${items[@]}"
}

# Pick a version from a tool directory
pick_version() {
  local tool_name="$1"
  local tool_dir="$DIR/../$tool_name"

  local files=()
  while IFS= read -r f; do
    files+=("$f")
  done < <(ls "$tool_dir"/Dockerfile* 2>/dev/null | sort || true)

  [ ${#files[@]} -eq 0 ] && { ui::msgbox "Error" "No Dockerfiles found for $tool_name"; return 1; }
  if [ ${#files[@]} -eq 1 ]; then
    local base
    base=$(basename "${files[0]}")
    if [ "$base" = "Dockerfile" ]; then
      echo "latest"
    else
      local v="${base#Dockerfile}"
      v="${v#.}"; v="${v#_}"; v="${v#-}"
      echo "${v:-custom}"
    fi
    return 0
  fi

  local items=()
  for f in "${files[@]}"; do
    local base
    base=$(basename "$f")
    local version
    if [ "$base" = "Dockerfile" ]; then
      version="latest"
    else
      version="${base#Dockerfile}"
      version="${version#.}"
      version="${version#_}"
      version="${version#-}"
      [ -z "$version" ] && version="custom"
    fi
    items+=("$version" "$base" "OFF")
  done

  ui::radiolist "Select version — $tool_name" "${items[@]}"
}

interactive_build() {
  local tool
  tool=$(pick_tool "Build — Select Tool") || return
  [ -z "$tool" ] && return

  local version
  version=$(pick_version "$tool") || return
  [ -z "$version" ] && return

  if ! ui::confirm "Build $tool:$version?"; then
    return
  fi

  # Run with progress
  local tool_dir="$DIR/../$tool"
  local dockerfile
  dockerfile=$(builder::find_dockerfile "$tool_dir" "$version")

  # Validate first
  ui::info "Validating $tool/$dockerfile..."
  local val_output
  val_output=$(validate::run_all "$dockerfile" 2>&1 || true)
  ui::msgbox "Validation Results" "$val_output"

  # Build
  ui::info "Building $tool:$version..."
  (
    echo "Building $tool:$version..."
    docker build -t "$tool:$version" -f "$dockerfile" "$tool_dir" 2>&1
    echo "Done."
  )

  if ui::confirm "Convert $tool:$version to Singularity?"; then
    builder::convert "$tool:$version"
  fi
}

interactive_validate() {
  local tool
  tool=$(pick_tool "Validate — Select Tool") || return
  [ -z "$tool" ] && return

  local version
  version=$(pick_version "$tool") || return

  local tool_dir="$DIR/../$tool"
  local dockerfile

  if [ -n "$version" ] && [ "$version" != "latest" ]; then
    dockerfile=$(builder::find_dockerfile "$tool_dir" "$version")
  elif [ -f "$tool_dir/Dockerfile" ]; then
    dockerfile="$tool_dir/Dockerfile"
  else
    dockerfile=$(ls "$tool_dir"/Dockerfile.* 2>/dev/null | head -1 || true)
  fi

  if [ -z "$dockerfile" ] || [ ! -f "$dockerfile" ]; then
    ui::msgbox "Error" "No Dockerfile found for $tool"
    return
  fi

  local result
  result=$(validate::run_all "$dockerfile" 2>&1 || true)
  ui::msgbox "Validation: $tool" "$result"
}

interactive_init() {
  local type
  type=$(ui::radiolist "Init — Select Type" \
    "python"  "python:3.11-slim + uv" "OFF" \
    "r"       "rocker/rstudio:4.4.0"  "OFF" \
    "gpu"     "nvidia/cuda:12.1.1-*"  "OFF" \
    "generic" "ubuntu:22.04"          "OFF") || return
  [ -z "$type" ] && return

  local name
  name=$(ui::input "Tool Name" "Enter tool name (e.g. mytool):") || return
  [ -z "$name" ] && { ui::msgbox "Error" "Name is required"; return; }

  local version
  version=$(ui::input "Version" "Enter version (e.g. 1.0.0):") || return
  [ -z "$version" ] && { ui::msgbox "Error" "Version is required"; return; }

  if ! ui::confirm "Create $name ($type) v$version?"; then
    return
  fi

  (cd "$DIR/.." && scaffolder::generate "$type" "$name" "$version")
  ui::msgbox "Created" "  $name/Dockerfile.v$version\n  $name/README.md"
}

interactive_convert() {
  local tool
  tool=$(pick_tool "Convert — Select Tool") || return
  [ -z "$tool" ] && return

  local version
  version=$(pick_version "$tool") || return
  [ -z "$version" ] && return

  if ! ui::confirm "Convert $tool:$version to Singularity?"; then
    return
  fi

  if ui::whiptail_ok; then
    # Gauge uses format: XXX\n<percent>\n<text>\nXXX — send 50% as placeholder
    builder::convert "$tool:$version" 2>&1 | while IFS= read -r line; do
      echo "XXX"
      echo "50"
      echo "$line"
      echo "XXX"
    done | whiptail --title "Converting to Singularity" --gauge "" 10 70 0
  else
    builder::convert "$tool:$version"
  fi
}

interactive_doctor() {
  local report
  report=$(
    echo "bash: $(bash --version | head -1)"
    echo ""
    if command -v docker &>/dev/null; then
      echo "docker: $(docker --version 2>/dev/null)"
      docker info &>/dev/null && echo "  (daemon: running)" || echo "  (daemon: NOT running)"
    else
      echo "docker: NOT FOUND"
    fi
    echo ""
    if command -v singularity &>/dev/null; then
      echo "singularity: $(singularity --version 2>/dev/null)"
    elif command -v apptainer &>/dev/null; then
      echo "apptainer: $(apptainer --version 2>/dev/null)"
    else
      echo "singularity: not installed (optional)"
    fi
    echo ""
    if command -v whiptail &>/dev/null; then
      echo "whiptail: available"
    else
      echo "whiptail: NOT FOUND (install for TUI)"
    fi
  )
  ui::msgbox "dockage doctor" "$report"
}

run_dispatch() {
  case "${1:-}" in
    build)     shift; builder::build_main "$@" ;;
    validate)  shift
      _tool_name="${1:-}"
      [ -z "$_tool_name" ] && { echo "Error: tool name required" >&2; exit 1; }
      shift
      _tool_dir="$DIR/../$_tool_name"
      _tool_orig="$_tool_dir"
      _tool_dir="$(cd "$_tool_dir" 2>/dev/null && pwd)" || {
        echo "Error: tool directory not found: $_tool_orig" >&2; exit 1
      }
      _version=""
      _strict=false
      while [ $# -gt 0 ]; do
        case "$1" in
          --strict) _strict=true; shift ;;
          --*) echo "Error: unknown option $1" >&2; exit 1 ;;
          *)
            if [ -z "$_version" ]; then _version="$1"; else echo "Error: unexpected argument $1" >&2; exit 1; fi
            shift ;;
        esac
      done
      if [ -n "$_version" ]; then
        _dockerfile=$(builder::find_dockerfile "$_tool_dir" "$_version")
      else
        if [ -f "$_tool_dir/Dockerfile" ]; then _dockerfile="$_tool_dir/Dockerfile"
        else _dockerfile=$(ls "$_tool_dir"/Dockerfile.* 2>/dev/null | head -1 || true); fi
        [ -z "$_dockerfile" ] && { echo "Error: no Dockerfile found for $_tool_name" >&2; exit 1; }
      fi
      if $_strict; then validate::run_all "$_dockerfile" --strict
      else validate::run_all "$_dockerfile"; fi
      ;;
    init)      shift; (cd "$DIR/.." && scaffolder::scaffold_main "$@") ;;
    convert)   shift; builder::convert_main "$@" ;;
    doctor)
      echo "─── dockage doctor ──────────────────────"
      for check in bash docker singularity whiptail bats; do
        echo -n "  $(printf '%-13s' "$check")"
        case "$check" in
          bash)
            if [ "${BASH_VERSINFO:-0}" -ge 4 ]; then echo "[OK] v$BASH_VERSION"
            else echo "[WARNING] v$BASH_VERSION (≥ 4.0 recommended)"; fi ;;
          docker)
            if command -v docker &>/dev/null; then
              if docker info &>/dev/null; then echo "[OK] $(docker --version 2>/dev/null)"
              else echo "[WARNING] installed but daemon not running"; fi
            else echo "[MISSING] install: https://docs.docker.com/get-docker/"; fi ;;
          singularity)
            if command -v singularity &>/dev/null; then echo "[OK] $(singularity --version 2>/dev/null)"
            elif command -v apptainer &>/dev/null; then echo "[OK] $(apptainer --version 2>/dev/null)"
            else echo "[optional] not found — needed for convert"; fi ;;
          whiptail)
            if command -v whiptail &>/dev/null; then echo "[OK] $(whiptail --version 2>&1 | head -1)"
            else echo "[optional] not found — needed for TUI (Phase 2)"; fi ;;
          bats)
            if command -v bats &>/dev/null; then echo "[OK] $(bats --version 2>/dev/null)"
            else echo "[optional] not found — needed for tests"; fi ;;
        esac
      done
      echo "────────────────────────────────────────" ;;
    --help)    usage ;;
    --version) echo "dockage v0.1.0" ;;
    "")        if ui::whiptail_ok || ui::tty_ok; then interactive_main_menu; else usage; fi ;;
    *)         echo "Unknown command: $1" >&2; usage; exit 1 ;;
  esac
}

# ── Entry point ────────────────────────────
run_dispatch "$@"

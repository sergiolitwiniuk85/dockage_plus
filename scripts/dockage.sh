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
  health                    Scan all Dockerfiles for known issues
  doctor                    Check dependencies and environment

Options:
  --help     Show help for a command
  --version  Show version
EOF
}

# ── Interactive TUI ────────────────────────
interactive_main_menu() {
  while true; do
    local choice
    choice=$(ui::menu "dockage" \
      "BUILD"    "Build a Docker image (with validation)" \
      "VALIDATE" "Check a Dockerfile against repo conventions" \
      "INIT"     "Scaffold a new tool Dockerfile" \
      "CONVERT"  "Convert Docker image to Singularity" \
      "CHECK"    "Scan all Dockerfiles + dependency status" \
      "EXIT"     "Leave dockage") || exit 0

    case "$choice" in
      BUILD)    interactive_build ;;
      VALIDATE) interactive_validate ;;
      INIT)     interactive_init ;;
      CONVERT)  interactive_convert ;;
      CHECK)    interactive_health ;;
      EXIT)     exit 0 ;;
    esac
  done
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

  local tool_dir="$DIR/../$tool"
  local dockerfile
  dockerfile=$(builder::find_dockerfile "$tool_dir" "$version")

  # Validate first
  ui::info "Validating $tool/$dockerfile..."
  local val_output
  val_output=$(validate::run_all "$dockerfile" 2>&1 || true)
  ui::msgbox "Validation Results" "$val_output"

  # Delegate to builder::build (handles symlinks, GPG fix, lowercase tags)
  local tag; tag=$(builder::determine_tag "$tool" "$version")
  builder::build "$tool_dir" "$version"

  if ui::confirm "Convert $tag to Singularity?"; then
    builder::convert "$tag"
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

  local df; df="$DIR/../$name/Dockerfile.v$version"
  (cd "$DIR/.." && scaffolder::generate "$type" "$name" "$version")
  if [ -f "$df" ]; then
    echo "Opening $df in ${EDITOR:-nano}..."
    ${EDITOR:-nano} "$df"
  fi
  ui::msgbox "Created" "  $name/Dockerfile.v$version\n  $name/README.md"
}

interactive_convert() {
  # Check singularity/apptainer first
  if ! command -v singularity &>/dev/null && ! command -v apptainer &>/dev/null; then
    ui::msgbox "Singularity not found" \
      "Singularity/Apptainer is required for conversion.\n\nInstall it or run: bash install.sh"
    return
  fi

  local tool
  tool=$(pick_tool "Convert — Select Tool") || return
  [ -z "$tool" ] && return

  local version
  version=$(pick_version "$tool") || return
  [ -z "$version" ] && return

  local tag; tag=$(builder::determine_tag "$tool" "$version")
  local tool_lower; tool_lower=$(echo "$tool" | tr '[:upper:]' '[:lower:]')
  local _sif_name="${tool_lower}-${version}.sif"
  local _just_built=false

  # Check if Docker image exists locally
  if ! docker image inspect "$tag" &>/dev/null; then
    if ui::confirm "Docker image $tag not found locally.\n\nBuild it first?"; then
      local _tool_dir="$DIR/../$tool"
      local _dockerfile
      _dockerfile=$(builder::find_dockerfile "$_tool_dir" "$version") || {
        ui::msgbox "Error" "No Dockerfile found for $tool $version"
        return
      }
      builder::build "$_tool_dir" "$version"
      _just_built=true
    else
      ui::msgbox "Cannot convert" \
        "Build the image first:\n  dockage.sh build $tool $version\n\nOr pull it from Docker Hub:\n  docker pull $tag"
      return
    fi
  fi

  # If we just built it, skip the confirmation — user already chose Convert
  if $_just_built || ui::confirm "Convert $tag to Singularity?\n\nOutput: $_sif_name"; then
    builder::convert "$tag"
  fi

  if [ -f "$_sif_name" ]; then
    ui::msgbox "Done" "Converted $tag\n\nOutput: $(pwd)/$_sif_name"
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
      echo "whiptail: available (not required — select is the default UI)"
    else
      echo "whiptail: not needed (bash select handles navigation)"
    fi
  )
  ui::msgbox "dockage doctor" "$report"
}

# ── Health ──────────────────────────────────
# Static analysis of all Dockerfiles to detect known issues without building.
dockage_health() {
  local root="$DIR/.."

  local total=0 ok=0 warn=0

  printf "\n─── dockage health ─────────────────────\n"
  printf "  %-28s %-33s  %s\n" "TOOL" "FROM" "STATUS"
  printf "  %-28s %-33s  %s\n" "────" "────" "──────"

  for dir in "$root"/*/; do
    local name; name=$(basename "$dir")
    [ "$name" = "scripts" ] || [ "$name" = "tests" ] && continue
    [[ "$name" == .* ]] && continue

    # Find Dockerfile(s) in this tool directory
    local dockerfiles=()
    while IFS= read -r -d '' f; do
      dockerfiles+=("$f")
    done < <(find "$dir" -maxdepth 1 -name 'Dockerfile*' -type f -print0 2>/dev/null | sort -z)

    [ ${#dockerfiles[@]} -eq 0 ] && continue

    total=$((total + 1))

    # Use the primary Dockerfile (first one, typically Dockerfile)
    local primary="${dockerfiles[0]}"

    # Extract FROM image (first one, most relevant)
    local from
    from=$(grep '^FROM' "$primary" 2>/dev/null | head -1 | sed 's/^FROM //' | sed 's/ AS .*//')
    from="${from:-unknown}"

    local -a issues=()

    # Check each Dockerfile for known issues
    for df in "${dockerfiles[@]}"; do
      if grep -qiE '\b(sid|testing|unstable)\b' "$df" 2>/dev/null; then
        if ! grep -qE 'apt-key|gpg[^l]|--allow-unauthenticated|AllowInsecureRepositories' "$df" 2>/dev/null; then
          issues+=("GPG: $(basename "$df")")
        fi
      fi
      # Check for COPY Dockerfile /docker without proper file
      if grep -q 'COPY Dockerfile' "$df" 2>/dev/null; then
        local df_base; df_base=$(basename "$df")
        if [ "$df_base" != "Dockerfile" ] && [ ! -f "$dir/Dockerfile" ]; then
          issues+=("COPY: $(basename "$df") needs symlink")
        fi
      fi
    done

    local status
    if [ ${#issues[@]} -eq 0 ]; then
      status="OK"
      ok=$((ok + 1))
    else
      status="${issues[0]}"
      [ ${#issues[@]} -gt 1 ] && status+=" (+$((${#issues[@]}-1)))"
      warn=$((warn + 1))
    fi

    printf "  %-28s %-33s  %s\n" "$name" "${from:0:31}" "$status"
  done

  printf "  ─────────────────────────────────────────────\n"
  printf "  Total: %d | OK: %d | Warnings: %d\n" "$total" "$ok" "$warn"
  echo "────────────────────────────────────────"

  [ $warn -eq 0 ] || return 1
}

dockage_doctor() {
  echo "─── dockage doctor ──────────────────────"
  for check in bash docker singularity fzf bats; do
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
      fzf)
        if command -v fzf &>/dev/null; then echo "[OK] $(fzf --version 2>/dev/null)"
        else echo "[MISSING] needed for interactive menus — run: bash install.sh"; fi ;;
      bats)
        if command -v bats &>/dev/null; then echo "[OK] $(bats --version 2>/dev/null)"
        else echo "[optional] not found — needed for tests"; fi ;;
    esac
  done
  echo "────────────────────────────────────────"
}

interactive_health() {
  local report
  report=$( { dockage_health 2>&1 || true; echo ""; dockage_doctor 2>&1 || true; } )
  ui::msgbox "Check" "$report"
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
    health)    shift; dockage_health "$@" ;;
    doctor)    shift; dockage_doctor "$@" ;;
    --help)    usage ;;
    --version) echo "dockage v0.1.0" ;;
    "")        if ui::interactive; then interactive_main_menu; else usage; fi ;;
    *)         echo "Unknown command: $1" >&2; usage; exit 1 ;;
  esac
}

# ── Entry point ────────────────────────────
run_dispatch "$@"

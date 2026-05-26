#!/usr/bin/env bash
set -euo pipefail

builder::detect_versions() {
  local tool_dir="$1"
  local files=()
  while IFS= read -r f; do
    files+=("$f")
  done < <(ls "$tool_dir"/Dockerfile* 2>/dev/null | sort || true)

  if [ ${#files[@]} -eq 0 ]; then
    echo "Error: no Dockerfile found in $tool_dir" >&2
    return 1
  fi

  local -a versions=()
  local -a filenames=()
  for f in "${files[@]}"; do
    local base
    base=$(basename "$f")
    if [ "$base" = "Dockerfile" ]; then
      versions+=("latest")
    else
      local suffix="${base#Dockerfile}"
      local version
      case "$suffix" in
        .v*) version="${suffix#.v}" ;;
        _v*) version="${suffix#_v}"; version="v${version}" ;;
        -v*) version="${suffix#-v}"; version="v${version}" ;;
        .*)  version="${suffix#.}" ;;
        _*)  version="${suffix#_}" ;;
        -*)  version="${suffix#-}" ;;
        *)   version="$suffix" ;;
      esac
      versions+=("$version")
    fi
    filenames+=("$f")
  done

  if [ ${#versions[@]} -eq 1 ]; then
    echo "${versions[0]}"
    return 0
  fi

  echo "Available versions for $(basename "$tool_dir"):" >&2
  for i in "${!versions[@]}"; do
    echo "  $((i+1)). ${versions[$i]}" >&2
  done

  local choice
  printf "Select version (1-%s): " "${#versions[@]}" >&2
  read -r choice
  local idx=$((choice - 1))
  if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#versions[@]}" ]; then
    echo "${versions[$idx]}"
  else
    echo "Error: invalid selection" >&2
    return 1
  fi
}

builder::find_dockerfile() {
  local tool_dir="$1"
  local version="$2"

  if [ "$version" = "latest" ]; then
    if [ -f "$tool_dir/Dockerfile" ]; then
      echo "$tool_dir/Dockerfile"
      return 0
    fi
    echo "Error: Dockerfile (latest) not found in $tool_dir" >&2
    return 1
  fi

  local sep
  for sep in ".v" "." "_" "-" "_v" "-v"; do
    local f="$tool_dir/Dockerfile${sep}${version}"
    if [ -f "$f" ]; then
      echo "$f"
      return 0
    fi
  done

  echo "Error: Dockerfile version '$version' not found in $tool_dir" >&2
  return 1
}

builder::determine_tag() {
  local name="$1"
  local version="$2"
  echo "${name}:${version}"
}

builder::build() {
  local tool_dir="$1"
  local version="$2"
  local dry_run=false
  [ "${3:-}" = "--dry-run" ] && dry_run=true

  local dockerfile
  dockerfile=$(builder::find_dockerfile "$tool_dir" "$version")
  local name
  name=$(basename "$tool_dir")
  local tag
  tag=$(builder::determine_tag "$name" "$version")

  local cmd="docker build -t \"$tag\" -f \"$dockerfile\" \"$tool_dir\""

  if $dry_run; then
    echo "$cmd"
  else
    echo "Building $tag..."
    eval "$cmd"
  fi
}

builder::convert() {
  local tag="$1"
  local dry_run=false
  [ "${2:-}" = "--dry-run" ] && dry_run=true

  local name="${tag%%:*}"
  local version="${tag#*:}"
  local sif="${name}-${version}.sif"

  if ! command -v singularity &>/dev/null && ! command -v apptainer &>/dev/null; then
    echo "Error: singularity not found. Install Singularity or Apptainer first." >&2
    return 1
  fi

  # Check that the Docker image exists locally
  if ! docker image inspect "$tag" &>/dev/null; then
    echo "Error: Docker image '$tag' not found locally." >&2
    echo "  Build it first: dockage.sh build $name $version" >&2
    echo "  Or pull it:     docker pull $tag (if available on Docker Hub)" >&2
    return 1
  fi

  local cmd
  if command -v singularity &>/dev/null; then
    cmd="singularity build \"$sif\" docker-daemon://\"$tag\""
  else
    cmd="apptainer build \"$sif\" docker-daemon://\"$tag\""
  fi

  if $dry_run; then
    echo "$cmd"
  else
    echo "Converting $tag to Singularity..."
    echo "Output: $sif"
    eval "$cmd"
  fi
}

builder::build_main() {
  local tool_name="${1:-}"
  [ -z "$tool_name" ] && { echo "Error: tool name required" >&2; return 1; }
  shift

  local version=""
  local dry_run=false
  local skip_validate=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) dry_run=true; shift ;;
      --skip-validate) skip_validate=true; shift ;;
      --*) echo "Error: unknown option $1" >&2; return 1 ;;
      *)
        if [ -z "$version" ]; then
          version="$1"
        else
          echo "Error: unexpected argument $1" >&2
          return 1
        fi
        shift
        ;;
    esac
  done

  local tool_dir="$DIR/../$tool_name"
  tool_dir="$(cd "$tool_dir" 2>/dev/null && pwd)" || {
    echo "Error: tool directory not found: $tool_dir" >&2
    return 1
  }

  if [ -z "$version" ]; then
    version=$(builder::detect_versions "$tool_dir")
  fi

  local dockerfile
  dockerfile=$(builder::find_dockerfile "$tool_dir" "$version")

  if ! $skip_validate; then
    echo "Validating Dockerfile..."
    validate::run_all "$dockerfile" || true
  fi

  builder::build "$tool_dir" "$version" $($dry_run && echo "--dry-run" || true)

  local name
  name=$(basename "$tool_dir")
  local tag
  tag=$(builder::determine_tag "$name" "$version")

  echo ""
  if ui::confirm "Convert to Singularity?"; then
    builder::convert "$tag" $($dry_run && echo "--dry-run" || true)
  fi
}

builder::convert_main() {
  local tool_name="${1:-}"
  local version="${2:-}"
  [ -z "$tool_name" ] && { echo "Error: tool name required" >&2; return 1; }
  [ -z "$version" ] && { echo "Error: version required" >&2; return 1; }

  local tag
  tag=$(builder::determine_tag "$tool_name" "$version")
  echo "Using tag: $tag"
  builder::convert "$tag"
}

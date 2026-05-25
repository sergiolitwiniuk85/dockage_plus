#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for lib in "$DIR/libs/"*.sh; do
  . "$lib"
done

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  build <tool> [version]    Build Docker image (with optional validation)
  validate <tool> [version] Validate Dockerfile conventions
  init <type> <name> <ver>  Scaffold new tool Dockerfile
  convert <tool> <version>  Convert Docker image to Singularity

Options:
  --help     Show help for a command
  --version  Show version
EOF
}

case "${1:-}" in
  build)
    shift
    builder::build_main "$@"
    ;;
  validate)
    shift
    _tool_name="${1:-}"
    [ -z "$_tool_name" ] && { echo "Error: tool name required" >&2; exit 1; }
    shift
    _tool_dir="$DIR/../$_tool_name"
    _tool_orig="$_tool_dir"
    _tool_dir="$(cd "$_tool_dir" 2>/dev/null && pwd)" || {
      echo "Error: tool directory not found: $_tool_orig" >&2
      exit 1
    }

    _version=""
    _strict=false
    while [ $# -gt 0 ]; do
      case "$1" in
        --strict) _strict=true; shift ;;
        --*) echo "Error: unknown option $1" >&2; exit 1 ;;
        *)
          if [ -z "$_version" ]; then
            _version="$1"
          else
            echo "Error: unexpected argument $1" >&2
            exit 1
          fi
          shift
          ;;
      esac
    done

    if [ -n "$_version" ]; then
      _dockerfile=$(builder::find_dockerfile "$_tool_dir" "$_version")
    else
      if [ -f "$_tool_dir/Dockerfile" ]; then
        _dockerfile="$_tool_dir/Dockerfile"
      else
        _dockerfile=$(ls "$_tool_dir"/Dockerfile.* 2>/dev/null | head -1 || true)
        [ -z "$_dockerfile" ] && { echo "Error: no Dockerfile found for $_tool_name" >&2; exit 1; }
      fi
    fi

    if $_strict; then
      validate::run_all "$_dockerfile" --strict
    else
      validate::run_all "$_dockerfile"
    fi
    ;;
  init)
    shift
    (cd "$DIR/.." && scaffolder::scaffold_main "$@")
    ;;
  convert)
    shift
    builder::convert_main "$@"
    ;;
  --help)
    usage
    ;;
  --version)
    echo "dockage v0.1.0"
    ;;
  "")
    usage
    ;;
  *)
    echo "Unknown command: $1" >&2
    usage
    exit 1
    ;;
esac

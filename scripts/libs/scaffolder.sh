#!/usr/bin/env bash
set -euo pipefail

scaffolder::list_templates() {
  echo "python r gpu generic"
}

scaffolder::generate() {
  local type="$1"
  local name="$2"
  local version="$3"

  local dir="$name"
  mkdir -p "$dir"

  local dockerfile_content
  case "$type" in
    python)
      dockerfile_content="FROM python:3.11-slim
RUN pip install uv && uv pip install jupyterlab ipykernel papermill
COPY Dockerfile /docker/
RUN chmod -R 755 /docker"
      ;;
    r)
      dockerfile_content="FROM rocker/rstudio:4.4.0
COPY Dockerfile /docker/
RUN chmod -R 755 /docker"
      ;;
    gpu)
      dockerfile_content="FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04
COPY Dockerfile /docker/
RUN chmod -R 755 /docker"
      ;;
    generic)
      dockerfile_content="FROM ubuntu:22.04
COPY Dockerfile /docker/
RUN chmod -R 755 /docker"
      ;;
    *)
      echo "Error: unknown template type '$type' (use: python, r, gpu, generic)" >&2
      return 1
      ;;
  esac

  echo "$dockerfile_content" > "$dir/Dockerfile.v$version"

  cat > "$dir/README.md" << EOF
# $name

| Field | Value |
|-------|-------|
| Description | TODO |
| URL | TODO |
| Version | $version |
EOF

  echo "Created: $dir/Dockerfile.v$version"
  echo "Created: $dir/README.md"
}

scaffolder::scaffold_main() {
  local type="${1:-}"
  local name="${2:-}"
  local version="${3:-}"

  [ -z "$type" ] && { echo "Error: template type required (one of: python, r, gpu, generic)" >&2; return 1; }
  [ -z "$name" ] && { echo "Error: tool name required" >&2; return 1; }
  [ -z "$version" ] && { echo "Error: version required" >&2; return 1; }

  scaffolder::generate "$type" "$name" "$version"
}

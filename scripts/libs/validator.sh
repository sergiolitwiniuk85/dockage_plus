#!/usr/bin/env bash
set -euo pipefail

validate::check_conda() {
  local dockerfile="$1"
  local found=false

  while IFS= read -r line; do
    local lineno="${line%%:*}"
    local text="${line#*:}"
    printf "  %s conda: '%s' found (line %s)\n" "[WARNING]" "$text" "$lineno"
    found=true
  done < <(grep -n 'conda install\|miniconda\|mamba\|conda env create' "$dockerfile" 2>/dev/null || true)

  if ! $found; then
    printf "  %s conda: no conda usage detected\n" "[OK]"
  fi
}

validate::check_copyfile() {
  local dockerfile="$1"

  if grep -q 'COPY.*Dockerfile.*docker' "$dockerfile" 2>/dev/null &&
     grep -q 'RUN chmod' "$dockerfile" 2>/dev/null; then
    printf "  %s copyfile: COPY Dockerfile + RUN chmod found\n" "[OK]"
  else
    printf "  %s copyfile: 'COPY Dockerfile /docker/' or 'RUN chmod' missing\n" "[WARNING]"
  fi
}

validate::check_base_image() {
  local dockerfile="$1"
  local from_line
  from_line=$(grep '^FROM' "$dockerfile" 2>/dev/null | head -1 || true)

  if [ -z "$from_line" ]; then
    printf "  %s base_image: no FROM instruction found\n" "[WARNING]"
    return
  fi

  if echo "$from_line" | grep -q 'rocker/r'; then
    if echo "$from_line" | grep -q 'rocker/rstudio'; then
      printf "  %s base_image: rocker/rstudio detected\n" "[OK]"
    else
      printf "  %s base_image: rocker/r found but not rocker/rstudio\n" "[WARNING]"
    fi
  elif echo "$from_line" | grep -qi 'cuda\|nvidia'; then
    local version
    version=$(echo "$from_line" | sed 's/.*://' | sed 's/-.*//')
    if [ "$version" = "12.1.1" ]; then
      printf "  %s base_image: nvidia/cuda 12.1.1 detected\n" "[OK]"
    else
      printf "  %s base_image: nvidia/cuda version %s (expected 12.1.1)\n" "[WARNING]" "$version"
    fi
  else
    printf "  %s base_image: %s\n" "[OK]" "$(echo "$from_line" | sed 's/FROM //')"
  fi
}

validate::check_naming() {
  local dockerfile="$1"
  local filename
  filename=$(basename "$dockerfile")

  if [ "$filename" = "Dockerfile" ] || echo "$filename" | grep -q '^Dockerfile\.v'; then
    printf "  %s naming: %s is standard\n" "[OK]" "$filename"
  else
    printf "  %s naming: %s does not match Dockerfile or Dockerfile.v* pattern\n" "[WARNING]" "$filename"
  fi
}

validate::run_all() {
  local dockerfile="$1"
  local strict=false
  [ "${2:-}" = "--strict" ] && strict=true

  if [ ! -f "$dockerfile" ]; then
    echo "Error: Dockerfile not found: $dockerfile" >&2
    exit 1
  fi

  local tmpfile
  tmpfile=$(mktemp /tmp/dockage-validate-XXXXXX)

  printf "\342\224\200\342\224\200\342\224\200 dockage validator \342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\n"

  validate::check_conda "$dockerfile" >> "$tmpfile"
  validate::check_copyfile "$dockerfile" >> "$tmpfile"
  validate::check_base_image "$dockerfile" >> "$tmpfile"
  validate::check_naming "$dockerfile" >> "$tmpfile"

  local warnings=0
  while IFS= read -r line; do
    echo "$line"
    if [[ "$line" == *"[WARNING]"* ]]; then
      warnings=$((warnings + 1))
    fi
  done < "$tmpfile"

  rm -f "$tmpfile"

  printf "\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\342\224\200\n"
  echo "  $warnings warning(s) found. Use --strict to enforce."

  if $strict && [ "$warnings" -gt 0 ]; then
    exit 1
  fi
}

#!/usr/bin/env bash
# dockage — dependency installer
# Usage: bash install.sh [simple|full]
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERR]${NC} $*"; }

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${BOLD}  ⚓ dockage install${NC}"
echo "  ───────────────────────────────"
echo ""

# ── Mode selection ──────────────────────────
if [ "${1:-}" = "full" ]; then
  mode="full"
elif [ "${1:-}" = "simple" ]; then
  mode="simple"
else
  echo "  Select installation type:"
  echo "    1)  Simple  — just check Docker & bash"
  echo "    2)  Full    — install whiptail (TUI) + apptainer (Singularity) + bats (tests) (default)"
  echo ""
  printf "  Choice [1/2] (default: 2): "
  read -r choice
  case "$choice" in
    1|simple|s) mode="simple" ;;
    *)          mode="full" ;;
  esac
fi

echo ""

# ── Check core deps (always) ────────────────
info "bash ≥ 4.0: $(bash --version | head -1)"

if command -v docker &>/dev/null; then
  if docker info &>/dev/null; then
    info "docker:     $(docker --version 2>/dev/null)"
  else
    warn "docker:     installed but daemon not running"
  fi
else
  warn "docker:     not found — install from https://docs.docker.com/get-docker/"
fi

if command -v singularity &>/dev/null; then
  info "singularity: $(singularity --version 2>/dev/null)"
elif command -v apptainer &>/dev/null; then
  info "apptainer:  $(apptainer --version 2>/dev/null)"
elif [ "$mode" = "full" ]; then
  info "singularity: will be installed"
else
  info "singularity: not needed unless you deploy to HPC"
fi

# ── Optional deps (full only) ────────────────
if [ "$mode" = "full" ]; then
  echo ""
  echo "  ── Installing optional dependencies ──"

  # Detect package manager (prepend sudo if not root)
  _s=""
  [ "$(id -u)" -ne 0 ] && command -v sudo &>/dev/null && _s="sudo "
  if command -v apt-get &>/dev/null; then
    PKG="${_s}apt-get install -y"
  elif command -v dnf &>/dev/null; then
    PKG="${_s}dnf install -y"
  elif command -v yum &>/dev/null; then
    PKG="${_s}yum install -y"
  elif command -v brew &>/dev/null; then
    PKG="brew install"
  else
    PKG=""
  fi

  # whiptail
  if command -v whiptail &>/dev/null; then
    info "whiptail:   already installed"
  elif [ -n "$PKG" ]; then
    info "whiptail:   installing..."
    $PKG whiptail 2>/dev/null && info "whiptail:   installed" || warn "whiptail:   failed to install"
  else
    warn "whiptail:   install manually with your package manager"
  fi

  # apptainer (singularity fork, packaged in apt)
  _app_installed=false
  if command -v singularity &>/dev/null; then
    info "singularity: already installed"
    _app_installed=true
  elif command -v apptainer &>/dev/null; then
    info "apptainer:  already installed"
    _app_installed=true
  elif [ -n "$PKG" ]; then
    # Try apptainer first (apt), then singularity-ce, then go install
    if $PKG apptainer 2>/dev/null; then
      info "apptainer:  installed"
      _app_installed=true
    elif $PKG singularity-container 2>/dev/null; then
      info "singularity: installed via apt"
      _app_installed=true
    else
      warn "singularity: apt package not found. Install manually from:"
      warn "            https://docs.sylabs.io/guides/latest/admin-guide/installation.html"
    fi
  else
    warn "singularity: no package manager found — install manually from:"
    warn "            https://docs.sylabs.io/guides/latest/admin-guide/installation.html"
  fi

  # bats
  if command -v bats &>/dev/null; then
    info "bats:       already installed"
  elif [ -n "$PKG" ] && $PKG bats 2>/dev/null; then
    info "bats:       installed via apt"
  elif command -v npm &>/dev/null && npm install -g bats 2>/dev/null; then
    info "bats:       installed via npm"
  else
    warn "bats:       not installed (optional — only for running tests)"
    warn "            install from: https://github.com/bats-core/bats-core"
  fi
fi

# ── Doctor ──────────────────────────────────
echo ""
echo "  ───────────────────────────────"
bash "$DIR/dockage.sh" doctor
echo ""
echo -e "${BOLD}  Done.${NC}"
echo "  Run ./dockage.sh --help to get started."

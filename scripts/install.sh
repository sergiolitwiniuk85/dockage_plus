#!/usr/bin/env bash
# dockage — dependency installer
# Always installs everything needed. No mode selection.
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

# ── Check core deps ──────────────────────────
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

# ── Install dependencies ────────────────────
echo ""
echo "  ── Installing dependencies ──"

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

# apptainer (singularity fork, packaged in apt)
if command -v singularity &>/dev/null; then
  info "singularity: $(singularity --version 2>/dev/null)"
elif command -v apptainer &>/dev/null; then
  info "apptainer:  $(apptainer --version 2>/dev/null)"
elif [ -n "$PKG" ]; then
  if $PKG apptainer 2>/dev/null; then
    info "apptainer:  installed"
  elif $PKG singularity-container 2>/dev/null; then
    info "singularity: installed via apt"
  else
    warn "singularity: apt package not found. Install manually:"
    warn "            https://docs.sylabs.io/guides/latest/admin-guide/installation.html"
  fi
else
  warn "singularity: no package manager found — install manually:"
  warn "            https://docs.sylabs.io/guides/latest/admin-guide/installation.html"
fi

# bats
if command -v bats &>/dev/null; then
  info "bats:       $(bats --version 2>/dev/null)"
elif [ -n "$PKG" ] && $PKG bats 2>/dev/null; then
  info "bats:       installed via apt"
elif command -v npm &>/dev/null && npm install -g bats 2>/dev/null; then
  info "bats:       installed via npm"
else
  warn "bats:       not installed — install from https://github.com/bats-core/bats-core"
fi

# ── Doctor ──────────────────────────────────
echo ""
echo "  ───────────────────────────────"
bash "$DIR/dockage.sh" doctor
echo ""
echo -e "${BOLD}  Done.${NC}"
echo "  Run ./dockage.sh to start."

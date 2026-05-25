#!/usr/bin/env bash
# dockage — optional dependency installer
# Usage: bash install.sh
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERR]${NC} $*"; }

echo "─── dockage install ─────────────────────"
echo ""

# Detect package manager
if command -v apt-get &>/dev/null; then
  PKG="apt-get install -y"
elif command -v dnf &>/dev/null; then
  PKG="dnf install -y"
elif command -v yum &>/dev/null; then
  PKG="yum install -y"
elif command -v brew &>/dev/null; then
  PKG="brew install"
else
  warn "No supported package manager found (apt/dnf/yum/brew)."
  warn "Install manually: whiptail, bats"
  PKG=""
fi

# whiptail — TUI (Phase 2)
if command -v whiptail &>/dev/null; then
  info "whiptail already installed"
else
  if [ -n "$PKG" ]; then
    info "Installing whiptail..."
    $PKG whiptail 2>/dev/null || warn "Failed to install whiptail (try manually)"
  fi
fi

# bats — unit tests
if command -v bats &>/dev/null; then
  info "bats already installed"
else
  info "Installing bats..."
  if $PKG bats 2>/dev/null; then
    info "bats installed via package manager"
  elif command -v npm &>/dev/null && npm install -g bats 2>/dev/null; then
    info "bats installed via npm"
  elif command -v npx &>/dev/null && npx --yes bats &>/dev/null; then
    info "bats available via npx"
  else
    warn "bats not installed. Run tests manually or install from:"
    warn "  https://github.com/bats-core/bats-core"
  fi
fi

echo ""
echo "─── dockage doctor ──────────────────────"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$DIR/dockage.sh" doctor

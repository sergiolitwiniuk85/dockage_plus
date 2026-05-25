#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKAGE="$SCRIPT_DIR/../dockage.sh"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURES="$SCRIPT_DIR/fixtures"
PASS=0
FAIL=0

pass()  { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail()  { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }

title() { echo ""; echo "=== $1 ==="; }

cleanup() {
  rm -rf "$PROJECT_ROOT/test-tool-validate" "$PROJECT_ROOT/test-tool-build" "$PROJECT_ROOT/test-tool-scaffold" /tmp/dockage-test-*
}
trap cleanup EXIT

title "Integration: dockage.sh validate on good Dockerfile -> exit 0"
mkdir -p "$PROJECT_ROOT/test-tool-validate"
cp "$FIXTURES/Dockerfile.good" "$PROJECT_ROOT/test-tool-validate/Dockerfile"
if "$DOCKAGE" validate "test-tool-validate" 2>/dev/null; then
  pass "validate good Dockerfile exited 0"
else
  fail "validate good Dockerfile should exit 0"
fi

title "Integration: dockage.sh validate --strict on conda Dockerfile -> exit 1"
mkdir -p "$PROJECT_ROOT/test-tool-validate-conda"
cp "$FIXTURES/Dockerfile.conda" "$PROJECT_ROOT/test-tool-validate-conda/Dockerfile"
if "$DOCKAGE" validate "test-tool-validate-conda" --strict 2>/dev/null; then
  fail "validate --strict conda should exit 1"
else
  pass "validate --strict conda exited 1"
fi
rm -rf "$PROJECT_ROOT/test-tool-validate-conda"

title "Integration: dockage.sh build --dry-run prints docker command"
mkdir -p "$PROJECT_ROOT/test-tool-build"
cp "$FIXTURES/Dockerfile.good" "$PROJECT_ROOT/test-tool-build/Dockerfile"
output=$("$DOCKAGE" build "test-tool-build" --dry-run --skip-validate 2>/dev/null <<< "n") || true
if echo "$output" | grep -q "docker build"; then
  pass "build --dry-run prints docker command"
else
  fail "build --dry-run should print docker build command, got: $output"
fi
rm -rf "$PROJECT_ROOT/test-tool-build"

title "Integration: dockage.sh init generates correct files"
output=$("$DOCKAGE" init python test-tool-scaffold 1.2.3 2>/dev/null)
if [ -f "$PROJECT_ROOT/test-tool-scaffold/Dockerfile.v1.2.3" ]; then
  pass "init created Dockerfile.v1.2.3"
else
  fail "init should create Dockerfile.v1.2.3"
fi
if grep -q "FROM python:3.11-slim" "$PROJECT_ROOT/test-tool-scaffold/Dockerfile.v1.2.3"; then
  pass "init generated correct FROM line"
else
  fail "init should have FROM python:3.11-slim"
fi
if [ -f "$PROJECT_ROOT/test-tool-scaffold/README.md" ]; then
  pass "init created README.md"
else
  fail "init should create README.md"
fi
rm -rf "$PROJECT_ROOT/test-tool-scaffold"

echo ""
echo "====================="
echo "Results: $PASS passed, $FAIL failed"
echo "====================="
[ "$FAIL" -eq 0 ]

#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
TOTAL=0

pass() {
  TOTAL=$((TOTAL + 1))
  PASS=$((PASS + 1))
  echo "ok $TOTAL - $1"
}

fail() {
  TOTAL=$((TOTAL + 1))
  FAIL=$((FAIL + 1))
  echo "not ok $TOTAL - $1"
}

assert_file_exists() {
  if [ -f "$PROJECT_ROOT/$1" ]; then
    pass "file exists: $1"
  else
    fail "file exists: $1"
  fi
}

assert_dir_exists() {
  if [ -d "$PROJECT_ROOT/$1" ]; then
    pass "dir exists: $1"
  else
    fail "dir exists: $1"
  fi
}

assert_executable() {
  if [ -x "$PROJECT_ROOT/$1" ]; then
    pass "executable: $1"
  else
    fail "executable: $1"
  fi
}

assert_contains() {
  if grep -q "$2" "$PROJECT_ROOT/$1" 2>/dev/null; then
    pass "contains '$2': $1"
  else
    fail "contains '$2': $1"
  fi
}

echo "TAP version 14"
echo "# EKS Hybrid Simulator Platform - Test Suite"
echo ""

echo "# === Structure Tests ==="
for test_file in "$PROJECT_ROOT"/tests/structure/test-*.sh; do
  if [ -f "$test_file" ]; then
    source "$test_file"
  fi
done

echo ""
echo "# === Hook Tests ==="
for test_file in "$PROJECT_ROOT"/tests/hooks/test-*.sh; do
  if [ -f "$test_file" ]; then
    source "$test_file"
  fi
done

echo ""
echo "1..$TOTAL"
echo ""
echo "# Results: $PASS passed, $FAIL failed, $TOTAL total"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0

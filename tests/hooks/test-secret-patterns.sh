#!/usr/bin/env bash
# Secret scanning pattern tests

SCAN_SCRIPT="$PROJECT_ROOT/.claude/hooks/secret-scan.sh"

echo "# -- True Positive Tests --"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  [[ "$line" == \#* ]] && continue
  if bash "$SCAN_SCRIPT" "$line" 2>/dev/null; then
    fail "secret-scan should block: ${line:0:30}..."
  else
    pass "secret-scan blocks: ${line:0:30}..."
  fi
done < "$PROJECT_ROOT/tests/fixtures/secret-samples.txt"

echo "# -- False Positive Tests --"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  [[ "$line" == \#* ]] && continue
  if bash "$SCAN_SCRIPT" "$line" 2>/dev/null; then
    pass "secret-scan allows: ${line:0:30}..."
  else
    fail "secret-scan false positive: ${line:0:30}..."
  fi
done < "$PROJECT_ROOT/tests/fixtures/false-positives.txt"

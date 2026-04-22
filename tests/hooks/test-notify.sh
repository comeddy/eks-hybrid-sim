#!/usr/bin/env bash
# Behavioral tests for notify.sh

HOOK="$PROJECT_ROOT/.claude/hooks/notify.sh"

echo "# -- Notify Behavioral Tests --"

EXIT_CODE=0
bash "$HOOK" "Test Title" "Test Message" >/dev/null 2>&1 || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "notify exits 0 with valid args"
else
  fail "notify exits 0 with valid args (got $EXIT_CODE)"
fi

EXIT_CODE=0
bash "$HOOK" >/dev/null 2>&1 || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "notify exits 0 with no args"
else
  fail "notify exits 0 with no args (got $EXIT_CODE)"
fi

EXIT_CODE=0
bash "$HOOK" 'Title with "quotes"' 'Message with \backslash' >/dev/null 2>&1 || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "notify handles special characters safely"
else
  fail "notify handles special characters safely (got $EXIT_CODE)"
fi

if grep -q 'jq' "$HOOK"; then
  pass "notify uses jq for safe JSON construction"
else
  fail "notify uses jq for safe JSON construction"
fi

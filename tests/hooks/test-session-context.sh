#!/usr/bin/env bash
# Behavioral tests for session-context.sh

HOOK="$PROJECT_ROOT/.claude/hooks/session-context.sh"

echo "# -- Session Context Behavioral Tests --"

OUTPUT=$(bash "$HOOK" 2>&1) || true

if echo "$OUTPUT" | grep -q "=== Session Context ==="; then
  pass "session-context outputs header"
else
  fail "session-context outputs header"
fi

if echo "$OUTPUT" | grep -q "Project:"; then
  pass "session-context includes project name"
else
  fail "session-context includes project name"
fi

if echo "$OUTPUT" | grep -q "Recent Changes"; then
  pass "session-context includes recent changes"
else
  fail "session-context includes recent changes"
fi

EXIT_CODE=0
bash "$HOOK" >/dev/null 2>&1 || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "session-context exits with code 0"
else
  fail "session-context exits with code 0 (got $EXIT_CODE)"
fi

#!/usr/bin/env bash
# Behavioral tests for check-doc-sync.sh

HOOK="$PROJECT_ROOT/.claude/hooks/check-doc-sync.sh"

echo "# -- Check Doc Sync Behavioral Tests --"

TEMP_TF="$PROJECT_ROOT/modules/acm/_test_temp.tf"
touch "$TEMP_TF"
OUTPUT=$(bash "$HOOK" "modules/acm/main.tf" 2>&1) || true
rm -f "$TEMP_TF"
if echo "$OUTPUT" | grep -q "architecture.md"; then
  pass "check-doc-sync warns on modules/ change"
else
  fail "check-doc-sync warns on modules/ change"
fi

OUTPUT=$(bash "$HOOK" "eks-simulator-helm/values.yaml" 2>&1) || true
if echo "$OUTPUT" | grep -q "Helm chart changed"; then
  pass "check-doc-sync warns on helm chart change"
else
  fail "check-doc-sync warns on helm chart change"
fi

OUTPUT=$(bash "$HOOK" "variables.tf" 2>&1) || true
if echo "$OUTPUT" | grep -q "README.md"; then
  pass "check-doc-sync warns on variables.tf change"
else
  fail "check-doc-sync warns on variables.tf change"
fi

OUTPUT=$(bash "$HOOK" "values.yaml" 2>&1) || true
if echo "$OUTPUT" | grep -q "README.md"; then
  pass "check-doc-sync warns on values.yaml change"
else
  fail "check-doc-sync warns on values.yaml change"
fi

OUTPUT=$(bash "$HOOK" "README.md" 2>&1) || true
if [ -z "$OUTPUT" ]; then
  pass "check-doc-sync silent on unrelated file"
else
  fail "check-doc-sync silent on unrelated file"
fi

EXIT_CODE=0
bash "$HOOK" "anything" >/dev/null 2>&1 || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "check-doc-sync always exits 0"
else
  fail "check-doc-sync always exits 0 (got $EXIT_CODE)"
fi

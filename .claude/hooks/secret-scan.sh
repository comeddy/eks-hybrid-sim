#!/usr/bin/env bash
set -euo pipefail

INPUT="${1:-}"

if [ ${#INPUT} -gt 1000000 ]; then
  echo "BLOCKED: Input too large for secret scanning (${#INPUT} bytes)" >&2
  exit 1
fi

SECRET_PATTERNS=(
  'AKIA[0-9A-Z]{16}'
  'aws_secret_access_key\s*=\s*["\x27][A-Za-z0-9/+=]{40}'
  'password\s*=\s*["\x27][^\x27"]{8,}'
  'BEGIN\s+(RSA|DSA|EC|OPENSSH)\s+PRIVATE\s+KEY'
  'ghp_[A-Za-z0-9]{36}'
  'sk-[A-Za-z0-9_-]{20,}'
  'xox[baprs]-[A-Za-z0-9-]+'
  '(secret|token|key|credential)\s*[=:]\s*["\x27]?[0-9a-f]{40}'
)

BLOCKED=false

for pattern in "${SECRET_PATTERNS[@]}"; do
  if printf '%s' "$INPUT" | grep -qPi "$pattern" 2>/dev/null; then
    MATCH=$(printf '%s' "$INPUT" | grep -oPi "$pattern" 2>/dev/null | head -1)
    if [ -n "$MATCH" ]; then
      MASKED="${MATCH:0:4}****${MATCH: -4}"
      echo "BLOCKED: Potential secret detected (pattern: ${pattern:0:20}...): $MASKED" >&2
      BLOCKED=true
    fi
  fi
done

if [ "$BLOCKED" = true ]; then
  exit 1
fi

exit 0

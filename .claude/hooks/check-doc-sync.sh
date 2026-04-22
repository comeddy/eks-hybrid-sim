#!/usr/bin/env bash
set -euo pipefail

INPUT="${1:-}"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

check_file_in_dir() {
  local changed_file="$1"
  local dir="$changed_file"

  while [ "$dir" != "." ] && [ "$dir" != "/" ]; do
    dir=$(dirname "$dir")
    if [ -f "$PROJECT_ROOT/$dir/CLAUDE.md" ]; then
      return 0
    fi
  done
  return 1
}

WARNINGS=""

if echo "$INPUT" | grep -q "modules/"; then
  if [ -f "$PROJECT_ROOT/docs/architecture.md" ]; then
    TF_MTIME=$(find "$PROJECT_ROOT/modules" -name "*.tf" -newer "$PROJECT_ROOT/docs/architecture.md" 2>/dev/null | head -1)
    if [ -n "$TF_MTIME" ]; then
      WARNINGS="${WARNINGS}docs/architecture.md may need updating (modules/*.tf changed)\n"
    fi
  fi
fi

if echo "$INPUT" | grep -q "eks-simulator-helm/"; then
  WARNINGS="${WARNINGS}Helm chart changed - verify docs/architecture.md component section\n"
fi

if echo "$INPUT" | grep -q "variables.tf\|values.yaml"; then
  WARNINGS="${WARNINGS}Variable definitions changed - verify README.md config tables\n"
fi

if [ -n "$WARNINGS" ]; then
  echo "=== Doc Sync Warnings ==="
  echo -e "$WARNINGS"
fi

exit 0

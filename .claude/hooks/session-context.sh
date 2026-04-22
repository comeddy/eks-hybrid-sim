#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "=== Session Context ==="
echo "Project: EKS Hybrid Simulator Platform"
echo "Root: $PROJECT_ROOT"
echo ""

if command -v terraform &>/dev/null; then
  echo "Terraform: $(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4 || echo 'available')"
fi

if command -v helm &>/dev/null; then
  echo "Helm: $(helm version --short 2>/dev/null || echo 'available')"
fi

if command -v kubectl &>/dev/null; then
  CONTEXT=$(kubectl config current-context 2>/dev/null || echo "none")
  echo "K8s Context: $CONTEXT"
fi

echo ""
echo "=== Recent Changes ==="
git log --oneline -5 2>/dev/null || echo "No git history"
echo ""

CHANGED=$(git diff --name-only HEAD 2>/dev/null | head -10)
if [ -n "$CHANGED" ]; then
  echo "=== Uncommitted Changes ==="
  echo "$CHANGED"
fi

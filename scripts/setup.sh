#!/usr/bin/env bash
set -euo pipefail

echo "=== EKS Hybrid Simulator Platform Setup ==="
echo ""

check_tool() {
  local tool="$1"
  local min_version="${2:-}"
  if command -v "$tool" &>/dev/null; then
    local version
    version=$("$tool" version 2>/dev/null | head -1 || "$tool" --version 2>/dev/null | head -1 || echo "installed")
    echo "[OK] $tool: $version"
  else
    echo "[MISSING] $tool is not installed"
    return 1
  fi
}

echo "Checking prerequisites..."
MISSING=0
check_tool terraform || MISSING=$((MISSING + 1))
check_tool helm || MISSING=$((MISSING + 1))
check_tool kubectl || MISSING=$((MISSING + 1))
check_tool aws || MISSING=$((MISSING + 1))

echo ""
if [ "$MISSING" -gt 0 ]; then
  echo "WARNING: $MISSING tool(s) missing. Install them before proceeding."
  echo ""
fi

echo "Checking AWS authentication..."
if aws sts get-caller-identity &>/dev/null; then
  ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
  echo "[OK] AWS authenticated (Account: $ACCOUNT)"
else
  echo "[MISSING] AWS CLI not authenticated. Run 'aws configure' first."
fi

echo ""
echo "Checking EKS cluster access..."
if kubectl cluster-info &>/dev/null; then
  CONTEXT=$(kubectl config current-context)
  echo "[OK] Kubernetes cluster accessible (Context: $CONTEXT)"
else
  echo "[MISSING] No Kubernetes cluster access. Run 'aws eks update-kubeconfig --name <cluster>' first."
fi

echo ""
echo "Setting up environment..."
if [ ! -f envs/dev/terraform.tfvars ]; then
  if [ -f envs/dev/terraform.tfvars.example ]; then
    echo "Creating envs/dev/terraform.tfvars from example..."
    cp envs/dev/terraform.tfvars.example envs/dev/terraform.tfvars
    echo "[OK] terraform.tfvars created. Edit it with your values."
  else
    echo "[SKIP] No terraform.tfvars.example found."
  fi
else
  echo "[OK] envs/dev/terraform.tfvars already exists."
fi

echo ""
echo "Installing git hooks..."
if [ -f scripts/install-hooks.sh ]; then
  bash scripts/install-hooks.sh
fi

echo ""
echo "=== Setup complete ==="
echo "Next steps:"
echo "  1. Edit envs/dev/terraform.tfvars with your values"
echo "  2. cd envs/dev && terraform init"
echo "  3. terraform plan"
echo "  4. terraform apply"

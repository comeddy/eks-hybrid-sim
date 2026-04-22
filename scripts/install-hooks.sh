#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

mkdir -p "$HOOKS_DIR"

cat > "$HOOKS_DIR/commit-msg" << 'HOOK'
#!/usr/bin/env bash
COMMIT_MSG_FILE="$1"
sed -i '/^Co-Authored-By:/d' "$COMMIT_MSG_FILE"
HOOK

chmod +x "$HOOKS_DIR/commit-msg"

echo "[OK] Git hooks installed:"
echo "  - commit-msg: Removes Co-Authored-By lines"

#!/usr/bin/env bash
set -euo pipefail

TITLE="${1:-Claude Code Notification}"
MESSAGE="${2:-}"

if command -v notify-send &>/dev/null; then
  notify-send "$TITLE" "$MESSAGE" 2>/dev/null || true
fi

if command -v osascript &>/dev/null; then
  osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\"" 2>/dev/null || true
fi

WEBHOOK_URL="${CLAUDE_NOTIFY_WEBHOOK:-}"
if [ -n "$WEBHOOK_URL" ]; then
  curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"$TITLE\",\"message\":\"$MESSAGE\"}" \
    >/dev/null 2>&1 || true
fi

exit 0

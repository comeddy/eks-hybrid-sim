#!/usr/bin/env bash
set -euo pipefail

TITLE="${1:-Claude Code Notification}"
MESSAGE="${2:-}"

if command -v notify-send &>/dev/null; then
  notify-send "$TITLE" "$MESSAGE" 2>/dev/null || true
fi

if command -v osascript &>/dev/null; then
  SAFE_TITLE=$(printf '%s' "$TITLE" | sed 's/[\"\\]/\\&/g')
  SAFE_MESSAGE=$(printf '%s' "$MESSAGE" | sed 's/[\"\\]/\\&/g')
  osascript -e "display notification \"$SAFE_MESSAGE\" with title \"$SAFE_TITLE\"" 2>/dev/null || true
fi

WEBHOOK_URL="${CLAUDE_NOTIFY_WEBHOOK:-}"
if [ -n "$WEBHOOK_URL" ]; then
  if command -v jq &>/dev/null; then
    PAYLOAD=$(jq -n --arg t "$TITLE" --arg m "$MESSAGE" '{title:$t,message:$m}')
  else
    PAYLOAD=$(printf '{"title":"%s","message":"%s"}' \
      "$(printf '%s' "$TITLE" | sed 's/["\\/]/\\&/g')" \
      "$(printf '%s' "$MESSAGE" | sed 's/["\\/]/\\&/g')")
  fi
  curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    >/dev/null 2>&1 || true
fi

exit 0

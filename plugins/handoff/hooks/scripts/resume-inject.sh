#!/bin/bash
# Resume context injection for SessionStart and PostCompact hooks.
[ "${HANDOFF_DISABLED:-0}" = "1" ] && exit 0
STATE="${CLAUDE_PROJECT_DIR:-.}/.handoff/state.json"
[ -f "$STATE" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

SEV=$(jq -r '.severity // "READY"' "$STATE" 2>/dev/null)
case "$SEV" in CRITICAL) echo "HANDOFF: 🔴 CRITICAL";; IN_PROGRESS) echo "HANDOFF: 🟡 IN PROGRESS";; *) echo "HANDOFF: 🟢 READY";; esac

NEXT=$(jq -r '.resume.next // empty' "$STATE" 2>/dev/null)
[ -n "$NEXT" ] && echo "Resume: $NEXT"
FILES=$(jq -r '.resume.files // [] | join(", ")' "$STATE" 2>/dev/null)
[ -n "$FILES" ] && echo "Files: $FILES"

jq -r '.blockers // [] | .[] | "Blocker: \(.)"' "$STATE" 2>/dev/null
jq -r '.watch_out_for // [] | .[] | "Watch: \(.)"' "$STATE" 2>/dev/null

BUILD=$(jq -r '.health.build // empty' "$STATE" 2>/dev/null)
TESTS=$(jq -r '.health.tests // empty' "$STATE" 2>/dev/null)
[ -n "$BUILD" ] || [ -n "$TESTS" ] && echo "Health: build=${BUILD:-?} tests=${TESTS:-?}"

HOST=$(jq -r '.hostname // empty' "$STATE" 2>/dev/null)
SID=$(jq -r '.session_id // empty' "$STATE" 2>/dev/null)
CURRENT_HOST=$(hostname -s 2>/dev/null || echo 'unknown')
[ -n "$HOST" ] && [ "$HOST" = "$CURRENT_HOST" ] && [ -n "$SID" ] && [ "$SID" != "${CLAUDE_SESSION_ID:-}" ] && echo "Resumable: claude --resume $SID"

exit 0

#!/bin/bash
# SessionStart hook: smart reinject + auto-init.
# Provides state summary. For CRITICAL, notes /handoff:start availability.

[ "${HANDOFF_DISABLED:-0}" = "1" ] && exit 0

command -v jq >/dev/null 2>&1 || { echo "HANDOFF: jq required but not found. Install: brew install jq (macOS) or apt install jq (Linux)"; exit 0; }

source "$(dirname "$0")/state.sh"

HANDOFF_DIR="${CLAUDE_PROJECT_DIR:-.}/.handoff"

if [ ! -d "$HANDOFF_DIR" ]; then
  if git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    bash "$(dirname "$0")/auto-init.sh"
    STATE_DIR="${CLAUDE_PROJECT_DIR:-.}/.handoff"
    JSON_FILE="${STATE_DIR}/state.json"
    EVENTS_FILE="${STATE_DIR}/events.jsonl"
  else
    exit 0
  fi
fi

CURRENT_SESSION=$(json_get '.session_id' '')
if [ -z "$CURRENT_SESSION" ] || [ "$CURRENT_SESSION" != "${CLAUDE_SESSION_ID:-}" ]; then
  json_exists && rt_reset || json_init
fi

json_exists || exit 0

# Validate schema — reinitialize if corrupted or incompatible with current version
if ! state_validate; then
  json_init
  echo "HANDOFF: state.json invalid, reinitialized."
fi

SEV=$(json_get '.severity' 'READY')
case "$SEV" in CRITICAL) SEV_DISPLAY="🔴 CRITICAL";; IN_PROGRESS) SEV_DISPLAY="🟡 IN PROGRESS";; *) SEV_DISPLAY="🟢 READY";; esac

BRANCH=$(git -C "${CLAUDE_PROJECT_DIR:-.}" branch --show-current 2>/dev/null || echo "unknown")
echo "HANDOFF: ${SEV_DISPLAY} | branch: ${BRANCH}"

# --resume awareness: suggest protocol-level continuation when previous session is on same machine
PREV_HOST=$(json_get '._runtime.hostname' '')
PREV_SESSION=$(json_get '.session_id' '')
CURRENT_HOST=$(hostname -s 2>/dev/null || echo 'unknown')
if [ -n "$PREV_HOST" ] && [ "$PREV_HOST" = "$CURRENT_HOST" ] && [ -n "$PREV_SESSION" ] && [ "$PREV_SESSION" != "${CLAUDE_SESSION_ID:-}" ]; then
  echo "Resumable: claude --resume ${PREV_SESSION}"
fi

if session_memory_exists; then
  session_memory_format
fi

BLOCK_COUNT=$(jq '[.blockers[] | select(.resolved == false)] | length' "$JSON_FILE" 2>/dev/null)
BLOCK_COUNT="${BLOCK_COUNT:-0}"
[ "$BLOCK_COUNT" -gt 0 ] && { echo "BLOCKERS (${BLOCK_COUNT}):"; jq -r '.blockers[] | select(.resolved == false) | "  - \(.description)"' "$JSON_FILE" 2>/dev/null; }

NEXT=$(json_get '.resume.next' '')
[ -n "$NEXT" ] && echo "Resume: ${NEXT}"
FILES=$(jq -r '.resume.files | if length == 0 then "" else join(", ") end' "$JSON_FILE" 2>/dev/null)
[ -n "$FILES" ] && echo "Files: ${FILES}"
CTX=$(json_get '.resume.context' '')
[ -n "$CTX" ] && echo "Context: ${CTX}"

WATCH_COUNT=$(jq '.watch_out_for | length' "$JSON_FILE" 2>/dev/null)
[ "${WATCH_COUNT:-0}" -gt 0 ] && { echo "WATCH OUT:"; jq -r '.watch_out_for[] | "  - \(.)"' "$JSON_FILE" 2>/dev/null; }

FAIL_COUNT=$(jq '.failed | length' "$JSON_FILE" 2>/dev/null)
[ "${FAIL_COUNT:-0}" -gt 0 ] && { echo "FAILED (do not retry):"; jq -r '.failed[] | "  - \(.description): \(.error // "—")"' "$JSON_FILE" 2>/dev/null; }

BUILD=$(json_get '.health.build' ''); TESTS=$(json_get '.health.tests' '')
[ -n "$BUILD" ] || [ -n "$TESTS" ] && echo "Health: build=${BUILD:-?} tests=${TESTS:-?}"

if [ "$SEV" = "CRITICAL" ] || [ "$BLOCK_COUNT" -ge 3 ]; then
  echo "Severity is ${SEV} with ${BLOCK_COUNT} blocker(s). Full context available via /handoff:start."
else
  echo "Full state: .handoff/state.json"
fi

exit 0

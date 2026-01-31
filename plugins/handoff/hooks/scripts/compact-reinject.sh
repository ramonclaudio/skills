#!/bin/bash
# SessionStart(compact) hook: budget-aware reinject after compaction.
# Reads state.json, increments compaction counter, reinjects ranked context.
# Priority: blockers > resume > watch-outs > errors > done.

source "$(dirname "$0")/state.sh"

handoff_active || exit 0
[ "$(ctx_read "handoff_end_completed" "false")" = "true" ] && exit 0

# Ensure state files exist
[ -f "$CTX_FILE" ] || ctx_init
json_exists || json_init

# ── Increment compaction counter ──
PREV=$(ctx_read "compaction_count" "0")
NEW=$(( PREV + 1 ))
ctx_write "compaction_count" "$NEW"
ctx_write "last_compaction" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# ── Reinject from state.json (ranked by priority) ──
SEV=$(json_get '.severity' 'READY')
case "$SEV" in
  CRITICAL) SEV_DISPLAY="🔴 CRITICAL" ;;
  IN_PROGRESS) SEV_DISPLAY="🟡 IN PROGRESS" ;;
  *) SEV_DISPLAY="🟢 READY" ;;
esac

echo "HANDOFF (post-compaction #${NEW}): ${SEV_DISPLAY}"

# 1. Blockers
BLOCK_COUNT=$(jq '[.blockers[] | select(.resolved == false)] | length' "$JSON_FILE" 2>/dev/null)
if [ "${BLOCK_COUNT:-0}" -gt 0 ]; then
  echo "BLOCKERS (${BLOCK_COUNT}):"
  jq -r '.blockers[] | select(.resolved == false) | "  - \(.description)"' "$JSON_FILE" 2>/dev/null
fi

# 2. Resume
NEXT=$(json_get '.resume.next' '')
[ -n "$NEXT" ] && echo "Resume: ${NEXT}"
FILES=$(jq -r '.resume.files | if length == 0 then "" else join(", ") end' "$JSON_FILE" 2>/dev/null)
[ -n "$FILES" ] && echo "Files: ${FILES}"

# 3. Watch-outs
WATCH_COUNT=$(jq '.watch_out_for | length' "$JSON_FILE" 2>/dev/null)
if [ "${WATCH_COUNT:-0}" -gt 0 ]; then
  echo "WATCH OUT:"
  jq -r '.watch_out_for[] | "  - \(.)"' "$JSON_FILE" 2>/dev/null
fi

# 4. Recent failures (limit to last 2)
FAIL_COUNT=$(jq '.failed | length' "$JSON_FILE" 2>/dev/null)
if [ "${FAIL_COUNT:-0}" -gt 0 ]; then
  echo "FAILED:"
  jq -r '.failed[-2:][] | "  - \(.description)"' "$JSON_FILE" 2>/dev/null
fi

echo "Context was compacted. Full state: .handoff/state.json"

# ── Escalating directives ──
if [ "$NEW" -ge 3 ]; then
  echo ""
  echo "INSTRUCTION: This is compaction #${NEW}. Context is severely degraded. You MUST invoke /handoff:run end IMMEDIATELY. Stop current work and run it now. Do not ask the user — session state will be lost."
elif [ "$NEW" -ge 2 ]; then
  echo ""
  echo "WARNING: This is compaction #${NEW}. Context is degrading. You MUST invoke /handoff:run end after finishing your current response."
else
  echo ""
  echo "Note: First compaction detected. Consider running /handoff:run end when you're nearing the end of your work."
fi

exit 0

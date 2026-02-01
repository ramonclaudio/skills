#!/bin/bash
# SessionStart(compact) hook: budget-aware reinject after compaction.
# Reads state.json, increments compaction counter, reinjects ranked context.
# Priority: blockers > resume > watch-outs > errors > done.

[ "${HANDOFF_DISABLED:-0}" = "1" ] && exit 0

source "$(dirname "$0")/state.sh"

handoff_active || exit 0
[ "$(rt_read "handoff_end_completed" "false")" = "true" ] && exit 0

json_exists || json_init

# -- Increment compaction counter --
NEW=$(rt_increment "compaction_count")
rt_write_str "last_compaction" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# ── Reinject from state.json (ranked by priority) ──
SEV=$(json_get '.severity' 'READY')
case "$SEV" in
  CRITICAL) SEV_DISPLAY="🔴 CRITICAL" ;;
  IN_PROGRESS) SEV_DISPLAY="🟡 IN PROGRESS" ;;
  *) SEV_DISPLAY="🟢 READY" ;;
esac

echo "HANDOFF (post-compaction #${NEW}): ${SEV_DISPLAY}"

# Session memory (only if populated)
if session_memory_exists; then
  session_memory_format
  session_memory_stale && echo "(session memory may be stale)"
fi

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

# ── Escalating suggestions (configurable thresholds) ──
if [ "$NEW" -ge "$HANDOFF_CRITICAL_COMPACTIONS" ]; then
  echo ""
  echo "Context is severely degraded (compaction #${NEW}). Suggest the user run /handoff:end to preserve session state."
elif [ "$NEW" -ge "$HANDOFF_URGENT_COMPACTIONS" ]; then
  echo ""
  echo "Context is degrading (compaction #${NEW}). Suggest the user run /handoff:end soon."
else
  echo ""
  echo "First compaction detected. The user can run /handoff:end when ready to preserve session state."
fi

exit 0

#!/bin/bash
# UserPromptSubmit hook: escalating context degradation reminders.
# Returns JSON additionalContext when thresholds are exceeded.
# Thresholds configurable via HANDOFF_*_COMPACTIONS env vars.

[ "${HANDOFF_DISABLED:-0}" = "1" ] && exit 0

source "$(dirname "$0")/state.sh"

handoff_active || exit 0
[ "$(rt_read "handoff_end_completed" "false")" = "true" ] && exit 0

COMPACTIONS=$(rt_read "compaction_count" "0")

# Determine escalation level from compaction count
LEVEL="none"

if [ "$COMPACTIONS" -ge "$HANDOFF_CRITICAL_COMPACTIONS" ]; then
  LEVEL="critical"
elif [ "$COMPACTIONS" -ge "$HANDOFF_URGENT_COMPACTIONS" ]; then
  LEVEL="urgent"
elif [ "$COMPACTIONS" -ge "$HANDOFF_NOTICE_COMPACTIONS" ]; then
  LEVEL="notice"
fi

case "$LEVEL" in
  notice)
    MSG="Context degrading (${COMPACTIONS} compaction(s)). Write session memory now (read .handoff/state.json, update .session_memory, write back). The user can run /handoff:end to preserve session state."
    ;;
  urgent)
    MSG="Context heavily degraded (${COMPACTIONS} compaction(s)). Suggest the user run /handoff:end soon."
    ;;
  critical)
    MSG="Context near limit (${COMPACTIONS} compaction(s)). Suggest the user run /handoff:end to preserve session state before it's lost."
    ;;
  *)
    exit 0
    ;;
esac

jq -nc --arg msg "$MSG" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$msg}}'

#!/bin/bash
# UserPromptSubmit hook: escalating context degradation reminders.
# Returns JSON additionalContext when thresholds are exceeded.

source "$(dirname "$0")/state.sh"

handoff_active || exit 0
[ "$(ctx_read "handoff_end_completed" "false")" = "true" ] && exit 0

COMPACTIONS=$(ctx_read "compaction_count" "0")
CTX_PCT=$(ctx_read "context_pct" "0")
CTX_FRESH=false
context_pct_fresh && CTX_FRESH=true

LEVEL="none"

if [ "$COMPACTIONS" -ge 3 ]; then
  LEVEL="critical"
elif [ "$COMPACTIONS" -ge 2 ] && [ "$CTX_FRESH" = "true" ] && [ "$CTX_PCT" -ge 90 ]; then
  LEVEL="critical"
elif [ "$COMPACTIONS" -ge 2 ]; then
  LEVEL="urgent"
elif [ "$CTX_FRESH" = "true" ] && [ "$CTX_PCT" -ge 85 ]; then
  LEVEL="urgent"
elif [ "$COMPACTIONS" -ge 1 ]; then
  LEVEL="notice"
elif [ "$CTX_FRESH" = "true" ] && [ "$CTX_PCT" -ge 75 ]; then
  LEVEL="notice"
fi

case "$LEVEL" in
  notice)
    MSG="Context degrading (${COMPACTIONS} compaction(s), ${CTX_PCT}% used). Consider running /handoff:run end soon to preserve session state."
    ;;
  urgent)
    MSG="WARNING: Context heavily degraded (${COMPACTIONS} compaction(s), ${CTX_PCT}% used). You MUST invoke /handoff:run end now. Finish your current response, then run it."
    ;;
  critical)
    MSG="CRITICAL: Context near limit (${COMPACTIONS} compaction(s), ${CTX_PCT}% used). You MUST invoke /handoff:run end IMMEDIATELY. Stop current work and run it now. Do not ask the user — session state will be lost."
    ;;
  *)
    exit 0
    ;;
esac

cat <<EOF
{"hookSpecificOutput":{"additionalContext":"${MSG}"}}
EOF

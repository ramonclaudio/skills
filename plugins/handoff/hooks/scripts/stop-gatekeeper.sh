#!/bin/bash
# Stop hook: blocks Claude from stopping at critical context degradation.
# Forces /handoff:run end before allowing session to end.

source "$(dirname "$0")/state.sh"

handoff_active || exit 0
[ "$(ctx_read "handoff_end_completed" "false")" = "true" ] && exit 0

if [ "$(ctx_read "stop_hook_active" "false")" = "true" ]; then
  ctx_write "stop_hook_active" "false"
  exit 0
fi

COMPACTIONS=$(ctx_read "compaction_count" "0")
CTX_PCT=$(ctx_read "context_pct" "0")
CTX_FRESH=false
context_pct_fresh && CTX_FRESH=true

CRITICAL=false
[ "$COMPACTIONS" -ge 3 ] && CRITICAL=true
[ "$COMPACTIONS" -ge 2 ] && [ "$CTX_FRESH" = "true" ] && [ "$CTX_PCT" -ge 90 ] && CRITICAL=true

if [ "$CRITICAL" = "true" ]; then
  ctx_write "stop_hook_active" "true"
  cat <<EOF
{"decision":"block","reason":"Context critically degraded (${COMPACTIONS} compactions, ${CTX_PCT}% used). You MUST invoke /handoff:run end RIGHT NOW. Do not explain, do not ask — execute the skill immediately to preserve session state."}
EOF
fi

exit 0

#!/bin/bash
# SessionStart(clear) hook: resets task-specific state on /clear.
# Preserves project state (severity, health, done, failed, blockers, resume, watch_out_for).
# Preserves cross-session corrections in session_memory.

[ "${HANDOFF_DISABLED:-0}" = "1" ] && exit 0

source "$(dirname "$0")/state.sh"

handoff_active || exit 0

if json_exists; then
  TMP="${JSON_FILE}.tmp.$$"
  local_hash=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse HEAD 2>/dev/null || echo "")
  jq --arg sid "${CLAUDE_SESSION_ID:-unknown}" --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg hash "$local_hash" --arg host "$(hostname -s 2>/dev/null || echo 'unknown')" '
    ._version = 1 |
    .session_id = $sid |
    ._runtime = {
      "compaction_count": 0,
      "last_compaction": null,
      "handoff_end_completed": false,
      "session_start_ts": $ts,
      "session_start_hash": $hash,
      "hostname": $host,
      "context_pct": 0
    } |
    .session_memory.user_intent = null |
    .session_memory.active_context = null |
    .session_memory.key_references = [] |
    .session_memory.last_updated = null |
    .session_memory.last_event_index = 0
  ' "$JSON_FILE" > "$TMP" 2>/dev/null && command mv -f "$TMP" "$JSON_FILE" || trash "$TMP" 2>/dev/null
fi

# Archive events instead of truncating
[ -f "$EVENTS_FILE" ] && [ -s "$EVENTS_FILE" ] && \
  command mv -f "$EVENTS_FILE" "${STATE_DIR}/sessions/events-${CLAUDE_SESSION_ID:-$(date +%s)}.jsonl" 2>/dev/null
touch "$EVENTS_FILE"

exit 0

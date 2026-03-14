#!/bin/bash
# Lightweight auto-save on PreCompact.
# Captures session state from git + events.jsonl without health checks.
# Single-pass state write: one jq invocation, one disk write.

source "$(dirname "$0")/state.sh"

handoff_active || exit 0
[ "$(rt_read "handoff_end_completed" "false")" = "true" ] && exit 0
json_exists || json_init

DIR="${CLAUDE_PROJECT_DIR:-.}"

GIT_DIRTY=$(git -C "$DIR" status --porcelain 2>/dev/null | head -1)

# Done: git commits since session start
START_HASH=$(rt_read "session_start_hash" "")
if [ -n "$START_HASH" ]; then
  DONE_JSON=$(git -C "$DIR" log "${START_HASH}..HEAD" --format='%h %s' 2>/dev/null | head -20 | \
    jq -Rs 'split("\n") | map(select(. != "")) | map(split(" ") | {description: (.[1:] | join(" ")), ref: .[0]})' 2>/dev/null)
else
  DONE_JSON=$(git -C "$DIR" log -5 --format='%h %s' 2>/dev/null | \
    jq -Rs 'split("\n") | map(select(. != "")) | map(split(" ") | {description: (.[1:] | join(" ")), ref: .[0]})' 2>/dev/null)
fi
[ -z "$DONE_JSON" ] || [ "$DONE_JSON" = "[]" ] || [ "$DONE_JSON" = "null" ] && DONE_JSON="[]"

# Failed: bash errors from events (non-zero exit)
ERRORS=$(events_bash_errors 50)
FAIL_JSON="[]"
if [ -n "$ERRORS" ]; then
  FAIL_JSON=$(echo "$ERRORS" | jq -sc 'group_by(.cmd) | map({
    description: (.[0].cmd // "" | .[:100]),
    tried: .[0].cmd, error: ("exit " + (.[0].exit // "?")), why: null, need: null
  }) | .[-3:]' 2>/dev/null)
  [ -z "$FAIL_JSON" ] || [ "$FAIL_JSON" = "[]" ] && FAIL_JSON="[]"
fi

# Resume: recently modified files
RECENT_FILES=$(events_recent_files 5)
DIRTY_FILES=$(git -C "$DIR" diff --name-only 2>/dev/null | head -5)
ALL_FILES=$(printf '%s\n%s' "$RECENT_FILES" "$DIRTY_FILES" | sort -u | grep -v '^$' | head -5)

FILES_JSON="[]"
NEXT=""
if [ -n "$ALL_FILES" ]; then
  FILES_JSON=$(echo "$ALL_FILES" | jq -Rs 'split("\n") | map(select(. != ""))')
  LAST_EDIT=$(events_by_type "edit" 1 | jq -r '.file // empty' 2>/dev/null)
  [ -z "$LAST_EDIT" ] && LAST_EDIT=$(events_by_type "write" 1 | jq -r '.file // empty' 2>/dev/null)
  [ -n "$LAST_EDIT" ] && NEXT="Continue editing ${LAST_EDIT}" || NEXT="Continue work on $(echo "$ALL_FILES" | head -1)"
fi

# Resume context: session memory > git diff stat > fallback
SM_CTX=$(json_get '.session_memory.active_context' '')
if [ -n "$SM_CTX" ]; then
  CTX="$SM_CTX"
else
  DIFF_STAT=$(git -C "$DIR" diff --stat 2>/dev/null | tail -1)
  [ -n "$DIFF_STAT" ] && CTX="Uncommitted: ${DIFF_STAT}" || CTX="Auto-saved before compaction"
fi

# Severity: inferred from current signals, not ground truth.
# Auto-save has no health checks, severity is a best-effort snapshot.
# A stale build failure stays CRITICAL until rebuild or manual-end.
NEW_SEV="READY"
[ -n "$GIT_DIRTY" ] && NEW_SEV="IN_PROGRESS"

LAST_TEST=$(events_by_class "test" 1 | jq -r '.exit // "0"' 2>/dev/null)
[ -n "$LAST_TEST" ] && [ "$LAST_TEST" != "0" ] && NEW_SEV="IN_PROGRESS"

LAST_BUILD=$(events_by_class "build" 1 | jq -r '.exit // "0"' 2>/dev/null)
[ -n "$LAST_BUILD" ] && [ "$LAST_BUILD" != "0" ] && NEW_SEV="CRITICAL"

EVENT_IDX=$(events_count)

# Single-pass state write: one jq invocation, validated before commit.
tmp="${JSON_FILE}.tmp.$$"
jq \
  --argjson done "$DONE_JSON" \
  --argjson failed "$FAIL_JSON" \
  --argjson files "$FILES_JSON" \
  --arg next "$NEXT" \
  --arg ctx "$CTX" \
  --arg sev "$NEW_SEV" \
  --argjson idx "$EVENT_IDX" '
  .done = $done |
  .failed = $failed |
  .resume.files = $files |
  .resume.next = (if $next == "" then null else $next end) |
  .resume.context = $ctx |
  .severity = $sev |
  .session_memory.last_event_index = $idx |
  .source = "auto-save"
' "$JSON_FILE" > "$tmp" 2>/dev/null && json_commit "$tmp"

events_rotate
exit 0

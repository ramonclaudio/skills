#!/bin/bash
# Lightweight auto-save on PreCompact.
# Captures session state from git log + events without health checks.
# Generates HANDOFF.md + git notes automatically.
# Must complete in <10s — no user interaction, no expensive checks.

source "$(dirname "$0")/state.sh"

handoff_active || exit 0
[ "$(ctx_read "handoff_end_completed" "false")" = "true" ] && exit 0

DIR="${CLAUDE_PROJECT_DIR:-.}"

# Bootstrap state.json if missing (backward compat)
if ! json_exists; then
  json_init
fi

# ── Capture git state ──
BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null || echo "unknown")
GIT_DIRTY=$(git -C "$DIR" status --porcelain 2>/dev/null | head -1)
GIT_STATUS="clean"
[ -n "$GIT_DIRTY" ] && GIT_STATUS="dirty"
json_set_str '.git.branch' "$BRANCH"
json_set_str '.git.status' "$GIT_STATUS"

# ── Infer done items from git commits since session start ──
SESSION_TS=$(ctx_read "session_start_ts" "")
if [ -n "$SESSION_TS" ]; then
  COMMITS=$(git -C "$DIR" log --since="$SESSION_TS" --format="%h %s" 2>/dev/null | head -20)
else
  COMMITS=$(git -C "$DIR" log -5 --format="%h %s" 2>/dev/null)
fi

if [ -n "$COMMITS" ]; then
  DONE_JSON="["
  FIRST=true
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    HASH=$(echo "$line" | cut -d' ' -f1)
    MSG=$(echo "$line" | cut -d' ' -f2-)
    MSG_ESC=$(printf '%s' "$MSG" | jq -Rs '.')
    [ "$FIRST" = true ] && FIRST=false || DONE_JSON+=","
    DONE_JSON+="{\"description\":${MSG_ESC},\"ref\":\"${HASH}\"}"
  done <<< "$COMMITS"
  DONE_JSON+="]"
  json_set '.done' "$DONE_JSON"
fi

# ── Infer failed items from bash error events ──
ERROR_COUNT=$(jq '[.events[] | select(.type == "bash_error")] | length' "$JSON_FILE" 2>/dev/null)
if [ "${ERROR_COUNT:-0}" -gt 0 ]; then
  FAIL_JSON=$(jq '[.events[] | select(.type == "bash_error")] | group_by(.detail) | map({
    "description": (.[0].detail | split(": ") | .[1:] | join(": ") | .[:100]),
    "tried": .[0].detail,
    "error": .[0].detail,
    "why": null,
    "need": null
  }) | .[-3:]' "$JSON_FILE" 2>/dev/null)
  [ -n "$FAIL_JSON" ] && [ "$FAIL_JSON" != "null" ] && json_set '.failed' "$FAIL_JSON"
fi

# ── Infer resume from recently modified files ──
RECENT_FILES=$(jq -r '[.events[] | select(.type == "file_edit" or .type == "file_write") | .file] | unique | .[-5:][] // empty' "$JSON_FILE" 2>/dev/null)
DIRTY_FILES=$(git -C "$DIR" diff --name-only 2>/dev/null | head -5)
ALL_FILES=$(printf '%s\n%s' "$RECENT_FILES" "$DIRTY_FILES" | sort -u | grep -v '^$' | head -5)

if [ -n "$ALL_FILES" ]; then
  FILES_JSON=$(echo "$ALL_FILES" | jq -Rs 'split("\n") | map(select(. != ""))')
  json_set '.resume.files' "$FILES_JSON"
  json_set_str '.resume.context' "Auto-saved before compaction. These files were recently modified."
  json_set_str '.resume.next' "Continue working on recently modified files"
fi

# ── Infer severity ──
BUILD_ERRORS=$(jq '[.events[] | select(.type == "build_run") | select(.detail | startswith("exit 0") | not)] | length' "$JSON_FILE" 2>/dev/null)
TEST_ERRORS=$(jq '[.events[] | select(.type == "test_run") | select(.detail | startswith("exit 0") | not)] | length' "$JSON_FILE" 2>/dev/null)

if [ "${BUILD_ERRORS:-0}" -gt 0 ]; then
  json_set_str '.severity' "CRITICAL"
elif [ "${TEST_ERRORS:-0}" -gt 0 ] || [ -n "$GIT_DIRTY" ]; then
  json_set_str '.severity' "IN_PROGRESS"
else
  json_set_str '.severity' "READY"
fi

# ── Generate HANDOFF.md ──
state_to_markdown

# ── Write git notes ──
git_note_save

exit 0

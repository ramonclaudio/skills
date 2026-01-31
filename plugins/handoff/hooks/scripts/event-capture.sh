#!/bin/bash
# PostToolUse hook: continuous event capture.
# Logs significant tool events to state.json for auto-save to consume.
# Only captures: bash errors, test runs, file writes/edits.

source "$(dirname "$0")/state.sh"

handoff_active || exit 0
json_exists || exit 0

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[ -z "$TOOL" ] && exit 0

case "$TOOL" in
  Bash)
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
    [ -z "$CMD" ] && exit 0
    CMD_SHORT=$(printf '%.200s' "$CMD")
    EXIT=$(echo "$INPUT" | jq -r '(.tool_response.exitCode // .tool_response.exit_code // .tool_result.exitCode // 0) | tostring' 2>/dev/null)
    EXIT="${EXIT:-0}"
    if [ "$EXIT" != "0" ] && [ "$EXIT" != "null" ]; then
      event_add "bash_error" "exit ${EXIT}: ${CMD_SHORT}"
    fi
    if echo "$CMD" | grep -qiE '\b(test|jest|vitest|pytest|mocha|cargo test|go test)\b'; then
      event_add "test_run" "exit ${EXIT}: ${CMD_SHORT}"
    fi
    if echo "$CMD" | grep -qiE '\b(build|tsc|webpack|vite build|cargo build|go build)\b'; then
      event_add "build_run" "exit ${EXIT}: ${CMD_SHORT}"
    fi
    ;;
  Write)
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    [ -n "$FILE" ] && event_add "file_write" "$FILE" "$FILE"
    ;;
  Edit)
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    [ -n "$FILE" ] && event_add "file_edit" "$FILE" "$FILE"
    ;;
esac

exit 0

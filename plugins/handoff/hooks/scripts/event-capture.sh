#!/bin/bash
# PostToolUse + PostToolUseFailure: append classified tool events to events.jsonl.
# Classifies bash commands at capture time (test/build/lint/vcs/cmd).
# Uses hook_event_name to distinguish success from failure input schemas.
# Does NOT source state.sh — hot path, minimal deps only.

[ "${HANDOFF_DISABLED:-0}" = "1" ] && exit 0

STATE_DIR="${CLAUDE_PROJECT_DIR:-.}/.handoff"
[ -d "$STATE_DIR" ] || exit 0
EVENTS_FILE="${STATE_DIR}/events.jsonl"

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
case "$TOOL" in Bash|Write|Edit) ;; *) exit 0 ;; esac

TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
IS_FAILURE=$(echo "$INPUT" | jq -r 'if .hook_event_name == "PostToolUseFailure" then "true" else "false" end' 2>/dev/null)

case "$TOOL" in
  Bash)
    CMD=$(echo "$INPUT" | jq -r '(.tool_input.command // "")[:200]' 2>/dev/null)
    [ -z "$CMD" ] && exit 0
    CMD_JSON=$(printf '%s' "$CMD" | jq -Rs '.')
    # Classify at capture time — the producer has the context.
    CLASS="cmd"
    case "$CMD" in
      *test*|*vitest*|*jest*|*pytest*|*mocha*) CLASS="test" ;;
      *build*|*tsc*|*webpack*|*vite\ build*|*cargo\ build*|*go\ build*) CLASS="build" ;;
      *lint*|*eslint*|*oxlint*|*biome\ check*) CLASS="lint" ;;
      git\ *|gh\ *) CLASS="vcs" ;;
    esac
    if [ "$IS_FAILURE" = "true" ]; then
      # PostToolUseFailure: no tool_response — has error + is_interrupt fields.
      ERROR=$(echo "$INPUT" | jq -r '(.error // "")[:200]' 2>/dev/null)
      ERROR_JSON=$(printf '%s' "$ERROR" | jq -Rs '.')
      # Extract exit code from error string ("non-zero status code N") when available.
      EXIT=$(echo "$ERROR" | grep -oE 'status code [0-9]+' | grep -oE '[0-9]+')
      [ -z "$EXIT" ] && EXIT="error"
      echo "{\"ts\":\"${TS}\",\"type\":\"bash\",\"class\":\"${CLASS}\",\"cmd\":${CMD_JSON},\"exit\":\"${EXIT}\",\"error\":${ERROR_JSON}}" >> "$EVENTS_FILE"
    else
      # PostToolUse: has tool_response with exit code.
      EXIT=$(echo "$INPUT" | jq -r '(.tool_response.exitCode // .tool_response.exit_code // .tool_result.exitCode // 0) | tostring' 2>/dev/null)
      echo "{\"ts\":\"${TS}\",\"type\":\"bash\",\"class\":\"${CLASS}\",\"cmd\":${CMD_JSON},\"exit\":\"${EXIT:-0}\"}" >> "$EVENTS_FILE"
      # PR action: trigger auto-save
      echo "$CMD" | grep -qiE '\bgh pr (create|merge|close)\b' && [ "${EXIT:-0}" = "0" ] && \
        bash "$(dirname "$0")/auto-save.sh" &
    fi
    ;;
  Write|Edit)
    FILE_JSON=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty | @json' 2>/dev/null)
    [ -n "$FILE_JSON" ] || exit 0
    if [ "$IS_FAILURE" = "true" ]; then
      # File operation failed — capture the error for the event log.
      ERROR=$(echo "$INPUT" | jq -r '(.error // "")[:200]' 2>/dev/null)
      ERROR_JSON=$(printf '%s' "$ERROR" | jq -Rs '.')
      echo "{\"ts\":\"${TS}\",\"type\":\"$(echo "$TOOL" | tr 'A-Z' 'a-z')_error\",\"file\":${FILE_JSON},\"error\":${ERROR_JSON}}" >> "$EVENTS_FILE"
    else
      echo "{\"ts\":\"${TS}\",\"type\":\"$(echo "$TOOL" | tr 'A-Z' 'a-z')\",\"file\":${FILE_JSON}}" >> "$EVENTS_FILE"
    fi
    ;;
esac

exit 0

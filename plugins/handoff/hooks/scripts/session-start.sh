#!/bin/bash
# SessionStart hook: smart reinject + auto-init + auto-start.
# Auto-inits .handoff/ for git repos without it.
# Smart reinject provides enough context that /handoff:run start is rarely needed.
# Only forces full start for CRITICAL severity or 3+ blockers.

source "$(dirname "$0")/state.sh"

HANDOFF_DIR="${CLAUDE_PROJECT_DIR:-.}/.handoff"

# ── Auto-init: no .handoff/ but has git repo ──
if [ ! -d "$HANDOFF_DIR" ]; then
  if git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    bash "$(dirname "$0")/auto-init.sh"
    # Re-source after init created the dir
    STATE_DIR="${CLAUDE_PROJECT_DIR:-.}/.handoff"
    CTX_FILE="${STATE_DIR}/.context-state"
    JSON_FILE="${STATE_DIR}/state.json"
  else
    exit 0
  fi
fi

# ── Initialize context state on fresh/new session ──
CURRENT_SESSION=$(ctx_read "session_id" "")
if [ -z "$CURRENT_SESSION" ] || [ "$CURRENT_SESSION" != "${CLAUDE_SESSION_ID:-}" ]; then
  # Fresh session: init context tracking but preserve state.json if it exists
  ctx_init
  if ! json_exists; then
    json_init
  fi
fi

# ── Smart reinject from state.json ──
if json_exists; then
  SEV=$(json_get '.severity' 'READY')
  case "$SEV" in
    CRITICAL) SEV_DISPLAY="🔴 CRITICAL" ;;
    IN_PROGRESS) SEV_DISPLAY="🟡 IN PROGRESS" ;;
    *) SEV_DISPLAY="🟢 READY" ;;
  esac

  echo "HANDOFF: ${SEV_DISPLAY}"

  # Blockers (highest priority)
  BLOCK_COUNT=$(jq '[.blockers[] | select(.resolved == false)] | length' "$JSON_FILE" 2>/dev/null)
  BLOCK_COUNT="${BLOCK_COUNT:-0}"
  if [ "$BLOCK_COUNT" -gt 0 ]; then
    echo "BLOCKERS (${BLOCK_COUNT}):"
    jq -r '.blockers[] | select(.resolved == false) | "  - \(.description)"' "$JSON_FILE" 2>/dev/null
  fi

  # Resume point
  NEXT=$(json_get '.resume.next' '')
  [ -n "$NEXT" ] && echo "Resume: ${NEXT}"
  FILES=$(jq -r '.resume.files | if length == 0 then "" else join(", ") end' "$JSON_FILE" 2>/dev/null)
  [ -n "$FILES" ] && echo "Files: ${FILES}"
  CTX=$(json_get '.resume.context' '')
  [ -n "$CTX" ] && echo "Context: ${CTX}"

  # Watch-outs
  WATCH_COUNT=$(jq '.watch_out_for | length' "$JSON_FILE" 2>/dev/null)
  if [ "${WATCH_COUNT:-0}" -gt 0 ]; then
    echo "WATCH OUT:"
    jq -r '.watch_out_for[] | "  - \(.)"' "$JSON_FILE" 2>/dev/null
  fi

  # Failed items
  FAIL_COUNT=$(jq '.failed | length' "$JSON_FILE" 2>/dev/null)
  if [ "${FAIL_COUNT:-0}" -gt 0 ]; then
    echo "FAILED (do not retry):"
    jq -r '.failed[] | "  - \(.description): \(.error // "—")"' "$JSON_FILE" 2>/dev/null
  fi

  # Health
  BUILD=$(json_get '.health.build' '')
  TESTS=$(json_get '.health.tests' '')
  if [ -n "$BUILD" ] || [ -n "$TESTS" ]; then
    echo "Health: build=${BUILD:-?} tests=${TESTS:-?}"
  fi

  # Directive: only force full start for CRITICAL or many blockers
  if [ "$SEV" = "CRITICAL" ] || [ "$BLOCK_COUNT" -ge 3 ]; then
    echo "INSTRUCTION: Severity is ${SEV} with ${BLOCK_COUNT} blocker(s). You MUST invoke /handoff:run start for full context before proceeding. Do not ask the user — just run it."
  else
    echo "Full context: .handoff/HANDOFF.md and .handoff/state.json"
  fi

# ── Fallback: no state.json but HANDOFF.md exists ──
elif [ -f "${HANDOFF_DIR}/HANDOFF.md" ]; then
  SEVERITY=$(grep -m1 '^> Severity:' "${HANDOFF_DIR}/HANDOFF.md" | sed 's/^> Severity: //')
  RESUME_NEXT=$(grep -m1 '^\*\*Next:\*\*' "${HANDOFF_DIR}/HANDOFF.md" | sed 's/^\*\*Next:\*\* //')
  RESUME_FILES=$(grep -m1 '^\*\*Files:\*\*' "${HANDOFF_DIR}/HANDOFF.md" | sed 's/^\*\*Files:\*\* //')
  BLOCKER_COUNT=$(grep -c '^\- \[ \]' "${HANDOFF_DIR}/HANDOFF.md" 2>/dev/null || echo "0")

  [ -n "$SEVERITY" ] && echo "HANDOFF: ${SEVERITY}"
  [ -n "$RESUME_NEXT" ] && echo "Resume: ${RESUME_NEXT}"
  [ -n "$RESUME_FILES" ] && [ "$RESUME_FILES" != "-" ] && echo "Files: ${RESUME_FILES}"
  [ "$BLOCKER_COUNT" -gt 0 ] 2>/dev/null && echo "Blockers: ${BLOCKER_COUNT} active"
  echo "Full context: .handoff/HANDOFF.md | Thorough load: /handoff:run start"
fi

exit 0

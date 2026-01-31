#!/bin/bash
# Unified state management for handoff plugin.
# Two storage backends:
#   .context-state (key=value) — high-frequency context metrics
#   state.json (JSON) — structured session state
#
# Source from other scripts: source "$(dirname "$0")/state.sh"

STATE_DIR="${CLAUDE_PROJECT_DIR:-.}/.handoff"
CTX_FILE="${STATE_DIR}/.context-state"
JSON_FILE="${STATE_DIR}/state.json"

handoff_active() { [ -d "$STATE_DIR" ]; }
json_exists() { [ -f "$JSON_FILE" ]; }

# ── Context state (key=value, fast for statusline writes) ──

ctx_read() {
  local key="$1" default="${2:-}"
  if [ -f "$CTX_FILE" ]; then
    local val
    val=$(grep -m1 "^${key}=" "$CTX_FILE" 2>/dev/null | cut -d= -f2-)
    echo "${val:-$default}"
  else
    echo "$default"
  fi
}

ctx_write() {
  local key="$1" val="$2"
  handoff_active || return 0
  if [ -f "$CTX_FILE" ] && grep -q "^${key}=" "$CTX_FILE" 2>/dev/null; then
    local tmp="${CTX_FILE}.tmp.$$"
    sed "s|^${key}=.*|${key}=${val}|" "$CTX_FILE" > "$tmp" && command mv -f "$tmp" "$CTX_FILE"
  else
    echo "${key}=${val}" >> "$CTX_FILE"
  fi
}

ctx_init() {
  handoff_active || return 0
  cat > "$CTX_FILE" <<EOF
compaction_count=0
last_compaction=
context_pct=0
context_pct_updated=0
handoff_end_completed=false
stop_hook_active=false
session_id=${CLAUDE_SESSION_ID:-unknown}
session_start_ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
EOF
}

context_pct_fresh() {
  local updated
  updated=$(ctx_read "context_pct_updated" "0")
  local now
  now=$(date +%s)
  [ $(( now - updated )) -le 60 ]
}

# ── Session state (JSON, structured) ──

json_get() {
  local path="$1" default="${2:-}"
  if json_exists; then
    local val
    val=$(jq -r "${path} // empty" "$JSON_FILE" 2>/dev/null)
    echo "${val:-$default}"
  else
    echo "$default"
  fi
}

json_set() {
  local path="$1" val="$2"
  handoff_active && json_exists || return 0
  local tmp="${JSON_FILE}.tmp.$$"
  jq "${path} = ${val}" "$JSON_FILE" > "$tmp" 2>/dev/null && command mv -f "$tmp" "$JSON_FILE"
}

json_set_str() {
  local path="$1" val="$2"
  local escaped
  escaped=$(printf '%s' "$val" | jq -Rs '.')
  json_set "$path" "$escaped"
}

json_append() {
  local path="$1" val="$2"
  handoff_active && json_exists || return 0
  local tmp="${JSON_FILE}.tmp.$$"
  jq "${path} += [${val}]" "$JSON_FILE" > "$tmp" 2>/dev/null && command mv -f "$tmp" "$JSON_FILE"
}

json_init() {
  handoff_active || return 0
  cat > "$JSON_FILE" <<EOF
{
  "version": 1,
  "session_id": "${CLAUDE_SESSION_ID:-unknown}",
  "severity": "READY",
  "health": {"build": null, "tests": null, "lint": null},
  "git": {"branch": null, "status": null},
  "done": [],
  "failed": [],
  "blockers": [],
  "resume": {"next": null, "files": [], "context": null},
  "watch_out_for": [],
  "events": []
}
EOF
}

# ── Unified init ──

state_init() {
  ctx_init
  json_init
}

# ── Event helpers ──

event_add() {
  local type="$1" detail="$2" file="${3:-}"
  json_exists || return 0
  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  local file_json="null"
  [ -n "$file" ] && file_json=$(printf '%s' "$file" | jq -Rs '.')
  local detail_json
  detail_json=$(printf '%s' "$detail" | jq -Rs '.')
  json_append '.events' "{\"ts\":\"${ts}\",\"type\":\"${type}\",\"detail\":${detail_json},\"file\":${file_json}}"
  # cap at 50 events
  local count
  count=$(jq '.events | length' "$JSON_FILE" 2>/dev/null)
  if [ "${count:-0}" -gt 50 ]; then
    local tmp="${JSON_FILE}.tmp.$$"
    jq '.events = .events[-50:]' "$JSON_FILE" > "$tmp" 2>/dev/null && command mv -f "$tmp" "$JSON_FILE"
  fi
}

# ── Generate HANDOFF.md from state.json ──

state_to_markdown() {
  json_exists || return 0
  local md="${STATE_DIR}/HANDOFF.md"
  local sid
  sid=$(json_get '.session_id' 'unknown')
  local sev
  sev=$(json_get '.severity' 'READY')

  local sev_display
  case "$sev" in
    CRITICAL) sev_display="🔴 CRITICAL" ;;
    IN_PROGRESS) sev_display="🟡 IN PROGRESS" ;;
    *) sev_display="🟢 READY" ;;
  esac

  local dir="${CLAUDE_PROJECT_DIR:-.}"
  local branch
  branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "unknown")
  local dirty
  dirty=$(git -C "$dir" status --porcelain 2>/dev/null | head -1)
  local git_status
  [ -n "$dirty" ] && git_status="dirty" || git_status="clean"

  {
    echo "# Handoff"
    echo ""
    echo "> Session: ${sid}"
    echo "> Severity: ${sev_display}"
    echo ""
    echo "## Health"
    echo "| Check | Status |"
    echo "|-------|--------|"
    echo "| Build | $(json_get '.health.build' '⏸️ not run') |"
    echo "| Tests | $(json_get '.health.tests' '⏸️ not run') |"
    echo "| Lint | $(json_get '.health.lint' '⏸️ not run') |"
    echo ""
    echo "## Git"
    echo "- Branch: ${branch}"
    echo "- Status: ${git_status}"
    local commits
    commits=$(git -C "$dir" log -5 --format="%h %s" 2>/dev/null)
    if [ -n "$commits" ]; then
      echo "- Last commits:"
      echo '  ```'
      echo "$commits" | sed 's/^/  /'
      echo '  ```'
    fi
    echo ""
    echo "## Done"
    local done_count
    done_count=$(jq '.done | length' "$JSON_FILE" 2>/dev/null)
    if [ "${done_count:-0}" -eq 0 ]; then
      echo "_Nothing yet._"
    else
      jq -r '.done[] | "- [x] \(.description)\(if .ref then " (\(.ref))" else "" end)"' "$JSON_FILE" 2>/dev/null
    fi
    echo ""
    echo "## Failed"
    local fail_count
    fail_count=$(jq '.failed | length' "$JSON_FILE" 2>/dev/null)
    if [ "${fail_count:-0}" -eq 0 ]; then
      echo "_None._"
    else
      jq -r '.failed[] | "### \(.description)\n- **Tried:** \(.tried // "—")\n- **Error:** \(.error // "—")\n- **Why:** \(.why // "—")\n- **Need:** \(.need // "—")"' "$JSON_FILE" 2>/dev/null
    fi
    echo ""
    echo "## Blockers"
    local block_count
    block_count=$(jq '.blockers | length' "$JSON_FILE" 2>/dev/null)
    if [ "${block_count:-0}" -eq 0 ]; then
      echo "_None._"
    else
      jq -r '.blockers[] | "- [\(if .resolved then "x" else " " end)] \(.description)"' "$JSON_FILE" 2>/dev/null
    fi
    echo ""
    echo "## Watch Out For"
    local watch_count
    watch_count=$(jq '.watch_out_for | length' "$JSON_FILE" 2>/dev/null)
    if [ "${watch_count:-0}" -eq 0 ]; then
      echo "_None yet._"
    else
      jq -r '.watch_out_for[] | "- \(.)"' "$JSON_FILE" 2>/dev/null
    fi
    echo ""
    echo "## Resume"
    echo "**Next:** $(json_get '.resume.next' '—')"
    local files
    files=$(jq -r '.resume.files | if length == 0 then "-" else join(", ") end' "$JSON_FILE" 2>/dev/null)
    echo "**Files:** ${files:--}"
    echo "**Context:** $(json_get '.resume.context' '—')"
  } > "$md"
}

# ── Git notes ──

git_note_save() {
  local dir="${CLAUDE_PROJECT_DIR:-.}"
  local head
  head=$(git -C "$dir" rev-parse HEAD 2>/dev/null) || return 0
  local compact_count
  compact_count=$(ctx_read "compaction_count" "0")
  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  local sev
  sev=$(json_get '.severity' 'READY')
  local resume
  resume=$(json_get '.resume.next' '')
  git -C "$dir" notes --ref=handoff add -f -m "handoff: ${sev} | compaction #${compact_count} | ${ts}
resume: ${resume}" HEAD 2>/dev/null
}

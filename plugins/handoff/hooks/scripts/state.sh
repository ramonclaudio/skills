#!/bin/bash
# State management for handoff plugin.
#
# Data flow:
#   SessionStart  --> session-start.sh  --> reads state.json --> injects context
#   Every tool    --> event-capture.sh   --> appends events.jsonl (classified at capture)
#   User prompt   --> prompt-reminder.sh --> reads _runtime   --> escalates
#   PreCompact    --> pre-compact.sh     --> auto-save.sh     --> writes state.json
#   Post-compact  --> compact-reinject.sh --> reads state.json --> re-injects
#   /handoff:end  --> skill (sonnet)     --> writes state.json + CONTEXT.md
#
# State transitions:
#   (no .handoff/)  --> auto-init  --> source:init,      severity:READY
#   PreCompact      --> auto-save  --> source:auto-save,  severity:inferred
#   /handoff:end    --> manual     --> source:manual-end, severity:checked
#
# Confidence: init < auto-save < manual-end
# Severity:   READY < IN_PROGRESS < CRITICAL
#
# Files:
#   state.json   -- single source of truth (structured state + _runtime counters)
#   events.jsonl -- append-only classified event log (no locking needed)
#   CONTEXT.md   -- project context with AUTO and CURATED sections
#
# No locking: Claude Code hooks run serially per session.
# Source from other scripts: source "$(dirname "$0")/state.sh"

STATE_DIR="${CLAUDE_PROJECT_DIR:-.}/.handoff"
JSON_FILE="${STATE_DIR}/state.json"
EVENTS_FILE="${STATE_DIR}/events.jsonl"

HANDOFF_NOTICE_COMPACTIONS="${HANDOFF_NOTICE_COMPACTIONS:-1}"
HANDOFF_URGENT_COMPACTIONS="${HANDOFF_URGENT_COMPACTIONS:-2}"
HANDOFF_CRITICAL_COMPACTIONS="${HANDOFF_CRITICAL_COMPACTIONS:-3}"
HANDOFF_MEMORY_STALE_EVENTS="${HANDOFF_MEMORY_STALE_EVENTS:-50}"

handoff_active() { [ -d "$STATE_DIR" ]; }
json_exists() { [ -f "$JSON_FILE" ]; }

# -- Runtime (_runtime section in state.json) --

rt_read() {
  local key="$1" default="${2:-}"
  json_exists || { echo "$default"; return; }
  local val
  val=$(jq -r "._runtime.${key} // empty" "$JSON_FILE" 2>/dev/null)
  echo "${val:-$default}"
}

rt_write() {
  local key="$1" val="$2"
  handoff_active && json_exists || return 0
  local tmp="${JSON_FILE}.tmp.$$"
  jq "._runtime.${key} = ${val}" "$JSON_FILE" > "$tmp" 2>/dev/null && command mv -f "$tmp" "$JSON_FILE" || rm -f "$tmp"
}

rt_write_str() {
  local key="$1" val="$2"
  rt_write "$key" "$(printf '%s' "$val" | jq -Rs '.')"
}

rt_increment() {
  local key="$1"
  handoff_active && json_exists || return 0
  local old new tmp="${JSON_FILE}.tmp.$$"
  old=$(jq -r "._runtime.${key} // 0" "$JSON_FILE" 2>/dev/null)
  new=$(( ${old:-0} + 1 ))
  jq "._runtime.${key} = ${new}" "$JSON_FILE" > "$tmp" 2>/dev/null && command mv -f "$tmp" "$JSON_FILE" || rm -f "$tmp"
  echo "$new"
}

rt_reset() {
  handoff_active && json_exists || return 0
  local tmp="${JSON_FILE}.tmp.$$"
  local head_hash
  head_hash=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse HEAD 2>/dev/null || echo "")
  jq --arg sid "${CLAUDE_SESSION_ID:-unknown}" --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg hash "$head_hash" --arg host "$(hostname -s 2>/dev/null || echo 'unknown')" '
    ._version = 1 |
    .session_id = $sid |
    ._runtime = { compaction_count:0, last_compaction:null, handoff_end_completed:false, session_start_ts:$ts, session_start_hash:$hash, hostname:$host, context_pct:0 }
  ' "$JSON_FILE" > "$tmp" 2>/dev/null && command mv -f "$tmp" "$JSON_FILE" || rm -f "$tmp"
  [ -f "$EVENTS_FILE" ] && [ -s "$EVENTS_FILE" ] && \
    command mv -f "$EVENTS_FILE" "${STATE_DIR}/sessions/events-${CLAUDE_SESSION_ID:-$(date +%s)}.jsonl" 2>/dev/null
  touch "$EVENTS_FILE"
}

# -- JSON state --

json_get() {
  local path="$1" default="${2:-}"
  json_exists || { echo "$default"; return; }
  local val
  val=$(jq -r "${path} // empty" "$JSON_FILE" 2>/dev/null)
  echo "${val:-$default}"
}

json_set() {
  local path="$1" val="$2"
  handoff_active && json_exists || return 0
  local tmp="${JSON_FILE}.tmp.$$"
  jq "${path} = ${val}" "$JSON_FILE" > "$tmp" 2>/dev/null && command mv -f "$tmp" "$JSON_FILE" || rm -f "$tmp"
}

json_set_str() {
  local path="$1" val="$2"
  json_set "$path" "$(printf '%s' "$val" | jq -Rs '.')"
}

# Write-time schema validation: validates tmp file before committing to state.json.
# Catches corruption at source instead of next session start.
json_commit() {
  local tmp="$1"
  [ -f "$tmp" ] || return 1
  jq -e '
    ._version == 1 and
    (.severity | IN("READY","IN_PROGRESS","CRITICAL")) and
    (.source | IN("init","auto-save","manual-end")) and
    (.done | type == "array") and
    (.failed | type == "array") and
    (.blockers | type == "array") and
    (.resume.files | type == "array")
  ' "$tmp" >/dev/null 2>&1 || {
    rm -f "$tmp"
    return 1
  }
  command mv -f "$tmp" "$JSON_FILE"
}

# -- Severity (validated, tracks current state) --

severity_set() {
  case "$1" in READY|IN_PROGRESS|CRITICAL) ;; *) return 1 ;; esac
  json_set_str '.severity' "$1"
}

# -- Events (append-only JSONL) --
# Event types: bash (cmd, class, exit), write (file), edit (file)
# Bash events classified at capture time: test, build, lint, vcs, cmd.

event_add() {
  local type="$1"; shift
  handoff_active || return 0
  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  local json="{\"ts\":\"${ts}\",\"type\":\"${type}\""
  while [ $# -ge 2 ]; do
    local key="$1" val="$2"; shift 2
    local val_json
    val_json=$(printf '%s' "$val" | jq -Rs '.')
    json+=",\"${key}\":${val_json}"
  done
  echo "${json}}" >> "$EVENTS_FILE"
}

events_by_type() {
  [ -f "$EVENTS_FILE" ] || return 0
  grep "\"type\":\"${1}\"" "$EVENTS_FILE" 2>/dev/null | tail -n "${2:-10}"
}

events_count() { [ -f "$EVENTS_FILE" ] && wc -l < "$EVENTS_FILE" 2>/dev/null | tr -d ' ' || echo "0"; }

# -- Event classification --
# Events are classified at capture time (event-capture.sh) via the "class" field.
# Classes: test, build, lint, vcs, cmd (default).

events_bash_errors() {
  [ -f "$EVENTS_FILE" ] || return 0
  grep '"type":"bash"' "$EVENTS_FILE" 2>/dev/null | grep -v '"exit":"0"' | tail -n "${1:-10}"
}

events_by_class() {
  [ -f "$EVENTS_FILE" ] || return 0
  grep "\"class\":\"${1}\"" "$EVENTS_FILE" 2>/dev/null | tail -n "${2:-10}"
}

events_recent_files() {
  [ -f "$EVENTS_FILE" ] || return 0
  grep -E '"type":"(edit|write)"' "$EVENTS_FILE" 2>/dev/null | \
    jq -rs '[.[].file | select(. != null)] | unique | .[-'"${1:-5}"':][]' 2>/dev/null
}

# -- Event log rotation (cap at 256KB) --
# Byte-based, not line-based: jq memory is proportional to bytes, not line count.

events_rotate() {
  [ -f "$EVENTS_FILE" ] || return 0
  local size
  size=$(wc -c < "$EVENTS_FILE" 2>/dev/null | tr -d ' ')
  [ "${size:-0}" -le 262144 ] && return 0
  mkdir -p "${STATE_DIR}/sessions"
  command mv -f "$EVENTS_FILE" "${STATE_DIR}/sessions/events-rotated-$(date +%s).jsonl" 2>/dev/null
  touch "$EVENTS_FILE"
}

# -- Session memory --

session_memory_exists() {
  json_exists || return 1
  [ "$(jq -r '(.session_memory // {}) | (.user_intent != null) or (.active_context != null) or ((.corrections // []) | length > 0) or ((.key_references // []) | length > 0)' "$JSON_FILE" 2>/dev/null)" = "true" ]
}

session_memory_stale() {
  session_memory_exists || return 0
  local idx
  idx=$(json_get '.session_memory.last_event_index' '0')
  [ $(( $(events_count) - ${idx:-0} )) -gt "$HANDOFF_MEMORY_STALE_EVENTS" ]
}

session_memory_format() {
  session_memory_exists || return 0
  local v
  v=$(json_get '.session_memory.active_context' ''); [ -n "$v" ] && echo "ACTIVE CONTEXT: $(printf '%.500s' "$v")"
  [ "$(jq '.session_memory.corrections // [] | length' "$JSON_FILE" 2>/dev/null)" -gt 0 ] && {
    echo "USER CORRECTIONS:"
    jq -r '.session_memory.corrections // [] | .[-3:][] | "  - \(.)"' "$JSON_FILE" 2>/dev/null
  }
  v=$(json_get '.session_memory.user_intent' ''); [ -n "$v" ] && echo "USER INTENT: $(printf '%.200s' "$v")"
  v=$(jq -r '.session_memory.key_references // [] | .[-3:] | join(", ")' "$JSON_FILE" 2>/dev/null); [ -n "$v" ] && echo "KEY REFS: ${v}"
}

# -- Init --

json_init() {
  handoff_active || return 0
  local head_hash
  head_hash=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse HEAD 2>/dev/null || echo "")
  cat > "$JSON_FILE" <<EOF
{
  "_version": 1,
  "source": "init",
  "session_id": "${CLAUDE_SESSION_ID:-unknown}",
  "severity": "READY",
  "_runtime": {
    "compaction_count": 0,
    "last_compaction": null,
    "handoff_end_completed": false,
    "session_start_ts": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
    "session_start_hash": "${head_hash}",
    "hostname": "$(hostname -s 2>/dev/null || echo 'unknown')",
    "context_pct": 0
  },
  "health": {"build": null, "tests": null, "lint": null},
  "done": [],
  "failed": [],
  "blockers": [],
  "resume": {"next": null, "files": [], "context": null},
  "watch_out_for": [],
  "session_memory": {
    "user_intent": null,
    "corrections": [],
    "active_context": null,
    "key_references": [],
    "last_updated": null,
    "last_event_index": 0
  }
}
EOF
  touch "$EVENTS_FILE"
}

# -- Validation --

state_validate() {
  json_exists || return 1
  jq -e '
    ._version == 1 and
    (.severity | IN("READY","IN_PROGRESS","CRITICAL")) and
    (.source | IN("init","auto-save","manual-end")) and
    (.done | type == "array") and
    (.failed | type == "array") and
    (.blockers | type == "array") and
    (.resume.files | type == "array")
  ' "$JSON_FILE" >/dev/null 2>&1
}


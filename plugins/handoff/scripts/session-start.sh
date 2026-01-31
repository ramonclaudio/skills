#!/usr/bin/env bash
# Handoff SessionStart hook

set -e

# Parse session ID from JSON input
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)

HANDOFF_DIR="${HANDOFF_DIR:-.handoff}"

if [ -f "$HANDOFF_DIR/HANDOFF.md" ]; then
    echo "📋 Handoff files detected at: $HANDOFF_DIR"
    [ -n "$SESSION_ID" ] && echo "Session: $SESSION_ID"
    echo "Run /handoff start to gather session context."
else
    echo "💡 No handoff files found. Run /handoff init to set up session continuity."
fi

exit 0

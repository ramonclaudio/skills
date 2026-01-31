#!/usr/bin/env bash
# Track subagent stop for handoff context

INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | grep -o '"agent_type":"[^"]*"' | cut -d'"' -f4)
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

DIR="${HANDOFF_DIR:-.handoff}"

if [ -n "$AGENT_TYPE" ] && [ -d "$DIR" ]; then
    echo "$TIMESTAMP | STOP  | $AGENT_TYPE" >> "$DIR/.subagents.log"
fi

exit 0

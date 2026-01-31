#!/usr/bin/env bash
cat > /dev/null

DIR="${HANDOFF_DIR:-.handoff}"
[[ -f "$DIR/HANDOFF.md" ]] && echo "💾 Session ending. Run /handoff end to save progress."

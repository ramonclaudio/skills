#!/bin/bash
# PreCompact hook: capture state snapshot + trigger auto-save.
# Writes git snapshot to .pre-compact, then runs auto-save for HANDOFF.md.

source "$(dirname "$0")/state.sh"

HANDOFF_DIR="${CLAUDE_PROJECT_DIR:-.}/.handoff"

if [ ! -d "$HANDOFF_DIR" ]; then
  exit 0
fi

ctx_write "pre_compact_ts" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# ── Git state snapshot (for END to reconstruct) ──
{
  echo "# Pre-Compaction Snapshot"
  echo "> Captured: $(date -u '+%Y-%m-%d %H:%M UTC')"
  echo ""
  echo "## Git State"
  echo "- Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
  echo "- Status:"
  git status -s 2>/dev/null | head -20 | sed 's/^/  /'
  echo ""
  echo "## Recent Commits"
  git log -5 --format="- %h %s" 2>/dev/null
  echo ""
  echo "## Modified Files"
  git diff --name-only 2>/dev/null | sed 's/^/- /'
} > "$HANDOFF_DIR/.pre-compact" 2>/dev/null

# ── Auto-save: lightweight END ──
bash "$(dirname "$0")/auto-save.sh"

exit 0

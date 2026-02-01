#!/bin/bash
# PreCompact hook: trigger auto-save before compaction.

[ "${HANDOFF_DISABLED:-0}" = "1" ] && exit 0

source "$(dirname "$0")/state.sh"

handoff_active || exit 0

bash "$(dirname "$0")/auto-save.sh"

exit 0

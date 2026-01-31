#!/bin/bash
# SessionStart(clear) hook: resets context state counters on /clear.

source "$(dirname "$0")/state.sh"

handoff_active || exit 0

ctx_init
if json_exists; then
  json_set '.events' '[]'
  json_set_str '.severity' "READY"
fi

exit 0

#!/usr/bin/env bash
# PreToolUse hook: block dangerous git operations.
# Exit 0 = allow, Exit 2 = block (reason on stderr).
set -euo pipefail

INPUT=$(cat)

if command -v jq &>/dev/null; then
  CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
else
  CMD=$(echo "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

[[ -z "$CMD" ]] && exit 0

case "$CMD" in
  git\ push*--force-with-lease*) ;;  # safe, allow
  git\ push*--force*|git\ push*\ -f\ *|git\ push*\ -f)
    echo "Blocked: force-push. Use --force-with-lease or git revert." >&2; exit 2 ;;
  git\ reset\ --hard*)
    echo "Blocked: reset --hard. Use --soft or stash." >&2; exit 2 ;;
  git\ *--no-verify*)
    echo "Blocked: --no-verify. Fix the hook instead." >&2; exit 2 ;;
  git\ *--no-gpg-sign*)
    echo "Blocked: --no-gpg-sign. Fix GPG config." >&2; exit 2 ;;
  git\ *commit.gpgsign=false*)
    echo "Blocked: disabling commit.gpgsign." >&2; exit 2 ;;
esac

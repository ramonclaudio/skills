#!/usr/bin/env bash
# Validate a conventional commit message.
# Usage: validate-commit-msg.sh "type(scope): description"
# Exit 0 = valid, Exit 1 = invalid (error on stderr).

MSG="${1:-}"

[[ -z "$MSG" ]] && { echo "Error: no message." >&2; exit 1; }
(( ${#MSG} > 72 )) && { echo "Error: ${#MSG} chars, max 72." >&2; exit 1; }
[[ ! "$MSG" =~ ^[a-z]+([(][a-z0-9._-]+[)])?:\ .+ ]] && { echo "Error: not conventional format." >&2; exit 1; }

DESC="${MSG#*: }"
[[ "${DESC:0:1}" =~ [A-Z] ]] && { echo "Error: description must start lowercase." >&2; exit 1; }
[[ "$MSG" == *. ]] && { echo "Error: no trailing period." >&2; exit 1; }
exit 0

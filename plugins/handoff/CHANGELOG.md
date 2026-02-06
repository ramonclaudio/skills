# Changelog

## 1.1.0

- Use `sonnet[1m]` (1M context) for both start and end skills
- Add `Bash(jq *)` and `Bash(hostname *)` to end skill allowed-tools
- Replace all `rm -f` with `trash` in state.sh (5 locations) and session-clear.sh
- Add `async: true` to event-capture hooks (PostToolUse, PostToolUseFailure)
- Enable model invocation for full agent autonomy

## 1.0.0

- Initial release
- SBAR-style session continuity with structured state
- `.handoff/state.json` single source of truth
- `.handoff/CONTEXT.md` with auto-regenerated and curated sections
- `.handoff/events.jsonl` append-only tool event log
- 9 hook scripts: auto-init, session-start, compact-reinject, session-clear, pre-compact, auto-save, event-capture, prompt-reminder, state library
- `/handoff:end` for session archival with health checks
- `/handoff:start` for deep context hydration

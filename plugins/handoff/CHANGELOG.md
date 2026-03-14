# Changelog

## 1.5.0

BREAKING: full rewrite.

- Rewrite as lean session quality gate (health checks + resume points + cross-machine state)
- Replace 8 hooks with 2: SessionStart and PostCompact (new v2.1.76 hook)
- Replace 9 bash scripts (~820 lines) with single `resume-inject.sh` (~28 lines)
- Drop event capture system (git tracks changes natively)
- Drop compaction monitoring and escalation (1M context makes this rare, PostCompact handles reinjection)
- Drop auto-init bootstrapping (skill creates `.handoff/` on first run)
- Drop session memory persistence (auto memory handles this natively)
- Drop `CONTEXT.md` regeneration (use `CLAUDE.md` instead)
- Drop `SubagentStart` context injection (subagents read `CLAUDE.md`)
- Simplify `state.json` schema: remove `_version`, `_runtime`, `source`, `failed`, `session_memory`
- Total: ~1000 lines reduced to ~130 lines

## 1.3.0

- Make `/handoff:start` user-invocable (remove `user-invocable: false`)
- Extract `agent_id`, `agent_type`, and `worktree` in event-capture hook
- Add "Handoff vs Auto-Memory" section to README
- Add troubleshooting note for `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS`
- Add `SubagentStart` hook to inject handoff context into subagents
- Capture `tool_use_id` from hook input in event-capture
- Replace all emdashes with commas, colons, and periods
- Compatible with suppressed async hook completion messages (v2.1.75)

## 1.2.0

- Upgrade to `opus` model for both start and end skills

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
- `.handoff/events.jsonl` append-only raw event log (bash cmd/exit, file writes/edits)
- 9 hook scripts: auto-init, session-start, compact-reinject, session-clear, pre-compact, auto-save, event-capture, prompt-reminder, state library
- `/handoff:end` for session archival with health checks
- `/handoff:start` for deep context hydration

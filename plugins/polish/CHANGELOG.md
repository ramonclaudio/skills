# Changelog

## 1.4.0

- Rename plugin from `simplify` to `polish` to avoid collision with bundled `/simplify` skill (Claude Code 2.1.63+)
- Differentiate from built-in `/simplify`: full codebase sweep vs recently changed files
- Rename `Task` tool to `Agent` (Claude Code 2.1.63)
- Move Phase 2-5 to references/workflow.md for progressive disclosure
- Add `[path]` to argument-hint for scoped analysis
- Use `${CLAUDE_SKILL_DIR}` for workflow.md reference path
- Add path scoping support to arguments
- Replace "comprehensive" AI vocabulary with plain language

## 1.2.0

- Drop `sonnet[1m]` for worker subagents, use `sonnet` (1M context unavailable on subscription plans)

## 1.1.0

- Use `sonnet[1m]` (1M context) for worker subagents
- Add tool restriction guidance to worker subagent prompts
- Enable model invocation for full agent autonomy

## 1.0.0

- Initial release
- 5-phase workflow: discovery, analysis, work queue, parallel simplification, report
- Up to 5 parallel background agents for file simplification
- Complexity scoring (0-10) with extended thinking
- `--dry-run` for report-only mode
- Skips generated, vendored, and config files

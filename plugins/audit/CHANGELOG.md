# Changelog

## 1.4.0

- Rename `Task` to `Agent` in allowed-tools and code examples
- Use `${CLAUDE_SKILL_DIR}` for reference file paths (checklists.md, rules.md)
- Add version field to plugin.json
- Add per-file sweep format for systematic Phase 2 audits

## 1.2.0

- Drop `sonnet[1m]` for subagents, use `sonnet` (1M context unavailable on subscription plans)

## 1.1.0

- Use `sonnet[1m]` (1M context) for all subagents
- Replace `TaskOutput` with `TaskGet` in allowed-tools
- Add `Write` to allowed-tools for fix agents
- Add read-only constraint to Phase 2 audit agents
- Enable model invocation for full agent autonomy

## 1.0.0

- Initial release
- 4 parallel audit agents: architecture, bugs, security, conventions
- 5-phase workflow with reconnaissance, audit, validation, ranking, and auto-fix
- Reference checklists and finding format rules
- Extended thinking support

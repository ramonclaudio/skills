# Changelog

## 1.4.0

- Upgrade all agents to opus (Opus 4.6 1M context now included for Max/Team/Enterprise)
- Add LSP tool access (goToDefinition, findReferences, hover) to audit agents for dead code detection and type analysis
- Remove per-file sweep format from rules.md (token waste on clean files)
- Drop `subagent_type` from Agent pseudocode (general-purpose is default)
- Validation and fix agents now use opus instead of sonnet

## 1.3.0

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

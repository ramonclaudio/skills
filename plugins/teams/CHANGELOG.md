# Changelog

## 1.3.0

- Fix SendMessage API shape throughout (use `to`/`message`/`summary` fields)
- Rename `Task` tool references to `Agent` (renamed in Claude Code 2.1.63)
- Add Quality Gates section (TeammateIdle, TaskCompleted, SubagentStop hooks)
- Add Verification team pattern
- Add context-centric decomposition principle to Phase 2
- Add model inheritance note to Phase 3
- Quantify token overhead (3-10x, ~7x in plan mode) and add context protection benefit
- Add ExitWorktree tool and WorktreeCreate/WorktreeRemove hooks to known limitations
- Add `permissionMode` field for per-teammate permission control
- Add `isolation: worktree` for git worktree isolation per teammate
- Add `maxTurns` field to limit agent turns
- Add `memory` field for persistent teammate memory (user/project/local scopes)
- Add `mcpServers` field to scope MCP servers to specific teammates
- Add `SubagentStart` hook event to quality gates documentation
- Add official team sizing guidance (3-5 teammates, 5-6 tasks per teammate)
- Add batch processing section and use case examples to patterns reference
- Update permissions section with per-teammate mode overrides
- Add spawn prompt template (EDIT/READ/DO NOT TOUCH structure) to coordination reference
- Add "Research and Implement" pattern (scour codebase + search docs + implement)
- Update Phase 5 spawn structure to reference canonical template
- Replace all emdashes with commas, colons, and periods

## 1.1.0

- Enable model invocation for full agent autonomy

## 1.0.0

- Initial release
- 6-phase orchestration: reconnaissance, decomposition, team design, task graph, spawn, coordinate
- 5 team patterns: Parallel Builders, Review Panel, Research Team, Adversarial Debug, Cross-Layer
- File ownership and conflict resolution protocols
- `--dry-run`, `--plan-approval`, `--delegate`, `--roles N` flags
- Coordination and patterns reference docs

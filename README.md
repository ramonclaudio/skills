# Skills

Plugin marketplace for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). 9 plugins, install what you need.

I use Claude Code for everything. Session context would vanish between runs, commits needed too many steps, codebases had no good way to audit themselves. So I built the tools I wanted and open sourced them. If they saved you time, [let me know](https://x.com/ramonclaudio).

## Install

> [!NOTE]
> Requires [Claude Code](https://docs.anthropic.com/en/docs/claude-code) v1.0.33+.

Add the marketplace:

```
/plugin marketplace add ramonclaudio/skills
```

Install any plugin:

```
/plugin install handoff@skills
```

The skill shows up as a `/command` you can run immediately.

## Plugins

Each plugin is a self-contained directory with a manifest, one or more skills, and optionally hooks, MCP servers, or reference docs.

| Plugin | What it ships | Requires |
| :--- | :--- | :--- |
| [handoff](./plugins/handoff) | 2 skills, 6 hooks | `git` |
| [qmd](./plugins/qmd) | 2 skills, 7 commands, 1 MCP server | `qmd`, `git` |
| [commit](./plugins/commit) | 1 skill | `git`, `gh` |
| [simplify](./plugins/simplify) | 1 skill | `git` |
| [audit](./plugins/audit) | 1 skill | `git` |
| [techdebt](./plugins/techdebt) | 1 skill | `git` |
| [gif](./plugins/gif) | 1 skill | `ffmpeg` |
| [frames](./plugins/frames) | 1 skill | `ffmpeg` |
| [teams](./plugins/teams) | 1 skill | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var |

## What's in each plugin

### handoff

Session continuity. Preserves context across sessions, machines, and compactions.

**Skills:**
- `/handoff:end` - archive session state with health checks (build/test/lint), severity, done/failed/blockers
- `/handoff:start` - auto-triggered on critical context loss. Deep rehydration with drift detection.

**Hooks (6):**
- `session-start.sh` - auto-init on startup/resume, context injection on compact
- `compact-reinject.sh` - re-inject context after compaction
- `session-clear.sh` - reset counters, archive events
- `pre-compact.sh` - auto-save before compaction
- `event-capture.sh` - capture tool events (async)
- `prompt-reminder.sh` - context degradation escalation

Hooks handle everything automatically. The only command you run is `/handoff:end` when you're done for the day.

### qmd

Reference repo manager. Clone GitHub repos, index them, search with BM25/vector/hybrid. All on-device.

**Skills:**
- `/qmd:add <url>` - clone + auto-detect file types + index + embed
- `qmd:search` - non-invocable guide teaching Claude when to use `qmd_query` vs `qmd_search` vs `qmd_vsearch`

**Commands (7):** `/qmd:update`, `/qmd:remove`, `/qmd:rename`, `/qmd:list`, `/qmd:context`, `/qmd:cleanup`, `/qmd:status`

**MCP server:** Exposes `qmd_search` (BM25), `qmd_vsearch` (vector), `qmd_query` (hybrid + LLM reranking), `qmd_get`, `qmd_multi_get`, `qmd_status`

### commit

Atomic commits with conventional format, grouped by architectural layer. GPG signs when available.

**Skill:** `/commit:commit [--analyze] [--pr] [--merge PR#]`

5-phase workflow: analysis, execution, verification, PR creation, merge.

### simplify

Analyze and simplify codebases using parallel background agents.

**Skill:** `/simplify:simplify [--dry-run]`

5-phase: discovery (glob all source), deep analysis (0-10 scoring), queue creation, parallel simplification (up to 5 agents), verification. Uses `opus` model.

### audit

Codebase audit with 4 parallel agents. Finds bugs, architectural rot, and dead weight.

**Skill:** `/audit:audit [--dry-run] [--recent] [path]`

4 agents run in parallel: Architecture/Design, Bugs/Logic, Security/Dependencies/Performance, Convention Compliance. Uses `opus` model.

### techdebt

End-of-session tech debt sweep.

**Skill:** `/techdebt:techdebt [--dry-run] [path]`

3 parallel agents scan for: duplicated code (>10 lines), dead exports, unused deps, stale TODOs, bloated files (>300 lines), naming inconsistencies.

### gif

Convert screen recordings to compressed GIFs with ffmpeg two-pass palette.

**Skill:** `/gif:gif <video-path> [--width N] [--fps N] [--speed N] [--crop] [--full]`

Handles HDR-to-SDR conversion. Defaults: 10fps, 640px width, bayer dither.

### frames

Extract video frames as images so Claude can analyze screen recordings, bug repros, and demos.

**Skill:** `/frames:frames <video-path>`

Smart sampling: 3-15 frames based on video length.

### teams

Orchestrate teams of Claude Code sessions working in parallel.

**Skill:** `/teams:teams <task> [--dry-run] [--plan-approval] [--delegate] [--roles N]`

6-phase: recon, decomposition, team design, task graph, spawn & brief, coordination. File ownership prevents conflicts. Uses `opus` model.

> [!IMPORTANT]
> Requires the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` environment variable.

## Plugin structure

Every plugin follows this layout:

```
plugins/{name}/
  .claude-plugin/plugin.json    manifest (name, version, description)
  skills/{skill-name}/SKILL.md  skill instructions
  hooks/hooks.json              event hooks (handoff only)
  hooks/scripts/*.sh            hook scripts (handoff only)
  commands/*.md                 extra commands (qmd only)
  .mcp.json                     MCP server config (qmd only)
  README.md                     plugin docs
```

## Version pinning

The marketplace tracks `main`. Pin to a specific version:

```
/plugin marketplace add ramonclaudio/skills#v1.1.0
```

## Updating

```
/plugin marketplace update skills
```

Or update a single plugin:

```
/plugin update handoff@skills
```

## Uninstall

```
/plugin uninstall handoff@skills
```

Remove the marketplace entirely:

```
/plugin marketplace remove skills
```

## Contributing

Ping me if there are any bugs or feature requests - [open an issue](https://github.com/ramonclaudio/skills/issues) or PR directly.

## License

[MIT](LICENSE)

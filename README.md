# Skills

Plugin marketplace for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). 9 plugins, install what you need.

I use Claude Code for everything. Session context would vanish between runs, commits needed too many steps, codebases had no good way to audit themselves. So I built the tools I wanted and open sourced them. If they saved you time, [let me know](https://x.com/ramonclaudio).

## Install

> [!NOTE]
> Requires [Claude Code](https://docs.anthropic.com/en/docs/claude-code) v1.0.33+.

<details>
<summary><strong>Prerequisites</strong></summary>

Different plugins have different dependencies. Install only what you need.

<details>
<summary><strong>Git</strong> (required by most plugins)</summary>

```sh
# macOS
brew install git
# or: xcode-select --install

# Linux (Debian/Ubuntu)
sudo apt-get install git

# Linux (Fedora)
sudo dnf install git

# Windows
winget install --id Git.Git -e --source winget
```

</details>

<details>
<summary><strong>GitHub CLI</strong> (required by <code>commit</code>)</summary>

```sh
# macOS
brew install gh

# Windows
winget install --id GitHub.cli
```

Linux — see the [official install guide](https://github.com/cli/cli/blob/trunk/docs/install_linux.md).

After installing, authenticate with `gh auth login`.

</details>

<details>
<summary><strong>QMD</strong> (required by <code>qmd</code>)</summary>

```sh
bun install -g github:tobi/qmd
```

Requires [Bun](https://bun.sh) >= 1.0.0. On macOS also install Homebrew SQLite: `brew install sqlite`.

</details>

<details>
<summary><strong>FFmpeg</strong> (required by <code>gif</code> and <code>frames</code>)</summary>

```sh
# macOS
brew install ffmpeg

# Linux (Debian/Ubuntu)
sudo apt-get install ffmpeg

# Linux (Fedora)
sudo dnf install ffmpeg

# Windows
winget install --id Gyan.FFmpeg
```

</details>

<details>
<summary><strong>Agent Teams env var</strong> (required by <code>teams</code>)</summary>

The `teams` plugin needs the experimental agent teams feature flag. Add it to your settings.

Global (all projects) — `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Project-only — `.claude/settings.local.json` in your repo root:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Or export it in your shell before launching Claude Code:

```sh
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

</details>

</details>

Add the marketplace:

```text
/plugin marketplace add ramonclaudio/skills
```

Then install any plugin:

```text
/plugin install handoff@skills
```

The skill shows up as a `/command` you can run immediately.

## Plugins

Each plugin is a self-contained directory with a manifest, one or more skills, and optionally hooks, MCP servers, or reference docs.

| Plugin | What it ships | Requires | Version |
| :--- | :--- | :--- | :--- |
| [handoff](./plugins/handoff) | 2 skills, 6 hooks | `git` | 1.1.0 |
| [qmd](./plugins/qmd) | 2 skills, 7 commands, 1 MCP server | `qmd`, `git` | 1.1.0 |
| [commit](./plugins/commit) | 1 skill | `git`, `gh` | 1.1.0 |
| [simplify](./plugins/simplify) | 1 skill | `git` | 1.1.0 |
| [audit](./plugins/audit) | 1 skill | `git` | 1.1.0 |
| [techdebt](./plugins/techdebt) | 1 skill | `git` | 1.1.0 |
| [gif](./plugins/gif) | 1 skill | `ffmpeg` | 1.1.0 |
| [frames](./plugins/frames) | 1 skill | `ffmpeg` | 1.1.0 |
| [teams](./plugins/teams) | 1 skill | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var | 1.1.0 |

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

```text
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

```text
/plugin marketplace add ramonclaudio/skills#v1.1.0
```

## Updating

```text
/plugin marketplace update skills
```

Or update a single plugin:

```text
/plugin update handoff@skills
```

## Uninstall

```text
/plugin uninstall handoff@skills
```

Remove the marketplace entirely:

```text
/plugin marketplace remove skills
```

## Contributing

Ping me if there are any bugs or feature requests - [open an issue](https://github.com/ramonclaudio/skills/issues) or PR directly.

## License

[MIT](LICENSE)

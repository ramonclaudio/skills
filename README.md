# Skills

A collection of the plugins, skills, agents, commands, hooks, and workflows I use in [Claude Code](https://docs.anthropic.com/en/docs/claude-code), open sourced for everyone. 9 plugins, grab what you need.

Context kept vanishing between sessions. Commits took too many steps. No good way to audit a codebase or coordinate parallel agents. So I built the tools I wanted and started publishing them here. Ping me if they save you time: [@ramonclaudio](https://x.com/ramonclaudio).

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
npm install -g @tobilu/qmd
# or
bun install -g @tobilu/qmd
```

Requires Node.js >= 22 or [Bun](https://bun.sh) >= 1.0.0. On macOS also install Homebrew SQLite: `brew install sqlite`.

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
| [handoff](./plugins/handoff) | 2 skills, 2 hooks | `git` | 1.6.0 |
| [qmd](./plugins/qmd) | 2 skills, 21 commands, 1 MCP server | `qmd`, `git` | 1.7.0 |
| [commit](./plugins/commit) | 1 skill, 1 hook, 2 scripts | `git`, `gh` | 1.5.0 |
| [polish](./plugins/polish) | 1 skill | `git` | 1.5.0 |
| [audit](./plugins/audit) | 1 skill, 1 script | `git` | 1.5.0 |
| [techdebt](./plugins/techdebt) | 1 skill, 1 script | `git` | 1.5.0 |
| [gif](./plugins/gif) | 1 skill | `ffmpeg` | 1.5.0 |
| [frames](./plugins/frames) | 1 skill | `ffmpeg` | 1.5.0 |
| [teams](./plugins/teams) | 1 skill | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var | 1.4.0 |

## What's in each plugin

### handoff

Session continuity. Preserves context across sessions, machines, and compactions.

**Skills:**
- `/handoff:end` - archive session state with health checks (build/test/lint), severity, done/failed/blockers
- `/handoff:start` - auto-triggered on critical context loss. Deep rehydration with drift detection.

**Hooks (2):**
- `SessionStart` - injects resume context on startup/resume
- `PostCompact` - re-injects context after compaction

Hooks run automatically. The only command you run is `/handoff:end` when you're done for the day.

### qmd

Reference repo manager. Clone GitHub repos, index them, search with BM25/vector/hybrid. All on-device.

**Skills:**
- `/qmd:add <url>` - clone + auto-detect file types + index + embed
- `qmd:search` - non-invocable guide teaching Claude how to compose effective queries with the `query` tool

**Commands (21):** `/qmd:update`, `/qmd:remove`, `/qmd:rename`, `/qmd:list`, `/qmd:context`, `/qmd:cleanup`, `/qmd:status`, `/qmd:embed`, `/qmd:pull`, `/qmd:get`, `/qmd:multi-get`, `/qmd:search`, `/qmd:vsearch`, `/qmd:query`, `/qmd:mcp`, `/qmd:collection-add`, `/qmd:collection-list`, `/qmd:collection-show`, `/qmd:collection-update-cmd`, `/qmd:collection-include`, `/qmd:collection-exclude`

**MCP server:** Exposes `query` (hybrid search with typed sub-queries), `get`, `multi_get`, `status`

### commit

Atomic commits with conventional format, grouped by architectural layer. GPG signs when available.

**Skill:** `/commit [--analyze] [--push] [--pr] [--merge PR#]`

5-phase workflow: analysis, execution, verification, push/PR creation, merge. Ships a `PreToolUse` hook that blocks force-push, `--no-verify`, and GPG bypass. Helper scripts validate commit message format and block dangerous git operations.

### polish

Full codebase sweep that scores every file 0-10 on polish potential and refines files scoring 5+. Unlike the built-in `/simplify` (which targets recently changed files), `/polish` analyzes the entire codebase.

**Skill:** `/polish [--dry-run] [path]`

5-phase: discovery (glob all source), deep analysis (0-10 scoring), queue creation, parallel refinement (up to 5 agents), verification. Uses `opus` model.

### audit

Codebase audit with 4 parallel agents. Finds bugs, architectural rot, and dead weight.

**Skill:** `/audit [--dry-run] [--recent] [path]`

4 agents run in parallel: Architecture/Design, Bugs/Logic, Security/Dependencies/Performance, Convention Compliance. Uses `opus` model.

### techdebt

End-of-session tech debt sweep.

**Skill:** `/techdebt [--dry-run] [path]`

3 parallel agents scan for: duplicated code (>10 lines), dead exports, unused deps, stale TODOs, bloated files (>300 lines), naming inconsistencies.

### gif

Convert screen recordings to compressed GIFs with ffmpeg two-pass palette.

**Skill:** `/gif <video-path> [--width N] [--fps N] [--speed N] [--crop] [--full]`

Handles HDR-to-SDR conversion. Defaults: 10fps, 640px width, bayer dither.

### frames

Extract video frames as images so Claude can analyze screen recordings, bug repros, and demos.

**Skill:** `/frames <video-path>`

Smart sampling: 3-15 frames based on video length.

### teams

Orchestrate teams of Claude Code sessions working in parallel.

**Skill:** `/teams <task> [--dry-run] [--plan-approval] [--delegate] [--roles N]`

6-phase: recon, decomposition, team design, task graph, spawn & brief, coordination. File ownership prevents conflicts. Uses `opus` model.

> [!IMPORTANT]
> Requires the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` environment variable.

## Plugin structure

Every plugin follows this layout:

```text
plugins/{name}/
  .claude-plugin/plugin.json         manifest (name, version, description)
  skills/{skill-name}/SKILL.md       skill instructions + frontmatter hooks
  skills/{skill-name}/scripts/*.sh   helper scripts (deterministic ops)
  skills/{skill-name}/references/    checklists, patterns, agent prompts
  hooks/hooks.json                   plugin-level event hooks (handoff)
  hooks/scripts/*.sh                 hook handler scripts (handoff)
  commands/*.md                      extra commands (qmd only)
  .mcp.json                          MCP server config (qmd only)
  README.md                          plugin docs
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

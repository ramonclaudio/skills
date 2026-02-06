# Skills

I use Claude Code all day. After hitting the same gaps over and over, I built these skills to fix them.

Custom [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills, installable individually as plugins.

[Setup](#setup) / [Skills](#available-skills) / [Usage](#usage) / [Version Pinning](#version-pinning)

## Setup

> [!NOTE]
> Requires [Claude Code](https://docs.anthropic.com/en/docs/claude-code) v1.0.33+.

Add the marketplace:

```bash
/plugin marketplace add ramonclaudio/skills
```

## Available Skills

| Plugin | Install | Description | Requires |
| :--- | :--- | :--- | :--- |
| [**handoff**](./plugins/handoff) | `/plugin install handoff@skills` | Session continuity. Structured handoffs preserve context between sessions. | `git` |
| [**qmd**](./plugins/qmd) | `/plugin install qmd@skills` | Reference repo manager. Clone GitHub repos, index with QMD, search with BM25/vector/hybrid — all on-device. | `qmd`, `git` |
| [**commit**](./plugins/commit) | `/plugin install commit@skills` | Atomic commits with conventional format, grouped by architectural layer. GPG signs when available. | `git`, `gh` |
| [**simplify**](./plugins/simplify) | `/plugin install simplify@skills` | Analyze and simplify entire codebases using parallel background agents. | `git` |
| [**audit**](./plugins/audit) | `/plugin install audit@skills` | Brutally honest codebase audit with parallel agents. Finds bugs, architectural rot, and dead weight. | `git` |
| [**techdebt**](./plugins/techdebt) | `/plugin install techdebt@skills` | Lightweight end-of-session tech debt sweep. Finds duplicated code, dead exports, unused deps, stale TODOs, and bloated files. | `git` |
| [**gif**](./plugins/gif) | `/plugin install gif@skills` | Convert screen recordings to compressed GIFs using ffmpeg two-pass palette method. | `ffmpeg` |
| [**teams**](./plugins/teams) | `/plugin install teams@skills` | Orchestrate teams of Claude Code sessions working in parallel with shared task lists and direct messaging. | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` |
| [**frames**](./plugins/frames) | `/plugin install frames@skills` | Extract video frames as images so Claude can analyze screen recordings, bug reproductions, and demos. | `ffmpeg` |

## Usage

After installing a plugin, invoke its skill:

<details>
<summary><strong>handoff</strong></summary>

Hooks handle everything automatically — auto-init on first run, context injection on startup, auto-save before compaction. The only user-invocable command is `/handoff:end` for session archival:

```bash
/handoff:end
```

</details>

<details>
<summary><strong>qmd</strong></summary>

```bash
/qmd:add vercel/next.js --dry-run
/qmd:add https://github.com/tobi/qmd
/qmd:add vercel/next.js --mask "**/*.{md,mdx}"
/qmd:add rust-lang/rust --full
/qmd:add lib1 lib2 lib3 --defer-embed
/qmd:update
/qmd:remove old-repo
/qmd:rename old-name new-name
/qmd:list
/qmd:list next.js/packages
/qmd:context list
/qmd:context add qmd://next.js "Next.js framework docs"
/qmd:context check
/qmd:cleanup
/qmd:status
```

</details>

<details>
<summary><strong>commit</strong></summary>

```bash
/commit:commit
/commit:commit --analyze
/commit:commit --pr
/commit:commit --merge 42
```

</details>

<details>
<summary><strong>simplify</strong></summary>

```bash
/simplify:simplify --dry-run
```

</details>

<details>
<summary><strong>audit</strong></summary>

```bash
/audit:audit --dry-run
/audit:audit --recent
/audit:audit src/
```

</details>

<details>
<summary><strong>techdebt</strong></summary>

```bash
/techdebt:techdebt --dry-run
/techdebt:techdebt src/
```

</details>

<details>
<summary><strong>teams</strong></summary>

```bash
/teams:teams Refactor the auth module into separate concerns
/teams:teams --dry-run Build a notification system
/teams:teams --plan-approval Migrate the database schema
/teams:teams --delegate Review PR #42 from three angles
/teams:teams --roles 3 Add caching to all API endpoints
```

</details>

<details>
<summary><strong>gif</strong></summary>

```bash
/gif:gif ~/Desktop/recording.mov
/gif:gif ~/Desktop/recording.mov --width 480
/gif:gif ~/Desktop/recording.mov --speed 3
/gif:gif ~/Desktop/recording.mov --crop
```

</details>

<details>
<summary><strong>frames</strong></summary>

```bash
/frames:frames ~/Desktop/recording.mov
```

</details>

See each plugin's README for full documentation.

## Version Pinning

The marketplace tracks the latest `main` branch. To pin to a specific version:

```bash
/plugin marketplace add ramonclaudio/skills#v1.1.0
```

## License

[MIT](LICENSE)

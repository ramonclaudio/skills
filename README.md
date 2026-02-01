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
|:---|:---|:---|:---|
| [**commit**](./plugins/commit) | `/plugin install commit@skills` | Atomic commits with conventional format, grouped by architectural layer. GPG signs when available. | `git`, `gh` |
| [**simplify**](./plugins/simplify) | `/plugin install simplify@skills` | Analyze and simplify entire codebases using parallel background agents | `git` |
| [**audit**](./plugins/audit) | `/plugin install audit@skills` | Brutally honest codebase audit with parallel agents. Finds bugs, architectural rot, and dead weight. | `git` |
| [**gif**](./plugins/gif) | `/plugin install gif@skills` | Convert screen recordings to compressed GIFs using ffmpeg two-pass palette method | `ffmpeg` |
| [**frames**](./plugins/frames) | `/plugin install frames@skills` | Extract video frames as images so Claude can analyze screen recordings, bug reproductions, and demos | `ffmpeg` |
| [**handoff**](./plugins/handoff) | `/plugin install handoff@skills` | Session continuity. Structured handoffs preserve context between sessions. | `git` |
| [**qmd**](./plugins/qmd) | `/plugin install qmd@skills` | Reference repo manager. Clone GitHub repos, index with QMD, search with BM25/vector/hybrid — all on-device. | `qmd`, `git` |

## Usage

After installing a plugin, invoke its skill:

```bash
/commit:run
/commit:run --pr
/simplify:run --dry-run
/gif:run ~/Desktop/recording.mov
/gif:run ~/Desktop/recording.mov --width 480
/frames:run ~/Desktop/recording.mov
/audit:run --dry-run
/audit:run --recent
/audit:run src/
/handoff:init
/handoff:start
/handoff:end
/qmd:add vercel/next.js --dry-run
/qmd:add https://github.com/tobi/qmd
/qmd:add vercel/next.js --mask "**/*.{md,mdx}"
/qmd:add rust-lang/rust --full
/qmd:add lib1 lib2 lib3 --defer-embed
/qmd:update
/qmd:remove old-repo
/qmd:cleanup
/qmd:status
```

See each plugin's README for full documentation.

---

> [!TIP]
> **Version Pinning** — The marketplace tracks the latest `main` branch. To pin to a specific version:
> ```bash
> /plugin marketplace add ramonclaudio/skills#v1.0.0
> ```

## License

[MIT](LICENSE)

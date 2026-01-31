# Skills

Custom [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills, installable individually as plugins.

## Setup

Requires [Claude Code](https://docs.anthropic.com/en/docs/claude-code) v1.0.33+.

Add the marketplace:

```
/plugin marketplace add ramonclaudio/skills
```

## Available Skills

| Plugin | Install | Description | Requires |
|--------|---------|-------------|----------|
| [**commit**](plugins/commit) | `/plugin install commit@skills` | Atomic commits with conventional format, grouped by architectural layer. GPG signs when available. | `git`, `gh` |
| [**simplify**](plugins/simplify) | `/plugin install simplify@skills` | Analyze and simplify entire codebases using parallel background agents | `git` |
| [**audit**](plugins/audit) | `/plugin install audit@skills` | Brutally honest codebase audit with parallel agents. Finds bugs, architectural rot, and dead weight. | `git` |
| [**gif**](plugins/gif) | `/plugin install gif@skills` | Convert screen recordings to compressed GIFs using ffmpeg two-pass palette method | `ffmpeg` |
| [**frames**](plugins/frames) | `/plugin install frames@skills` | Extract video frames as images so Claude can analyze screen recordings, bug reproductions, and demos | `ffmpeg` |

## Usage

After installing a plugin, invoke its skill:

```
/commit:run
/commit:run --pr
/simplify:run --dry-run
/gif:run ~/Desktop/recording.mov
/gif:run ~/Desktop/recording.mov --width 480
/frames:run ~/Desktop/recording.mov
/audit:run --dry-run
/audit:run --recent
/audit:run src/
```

See each plugin's README for full documentation.

## Version Pinning

The marketplace tracks the latest `main` branch. To pin to a specific version, use a ref when adding:

```
/plugin marketplace add ramonclaudio/skills#v1.0.0
```

## License

[MIT](LICENSE)

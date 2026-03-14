# Skills

Claude Code plugin marketplace — 9 installable plugins that extend Claude Code.

## Repo Structure

```
.claude-plugin/marketplace.json   # Central marketplace config
plugins/
  audit/          # Codebase audit (parallel agents)
  commit/         # Atomic conventional commits, GPG signed
  frames/         # Video frame extraction (ffmpeg)
  gif/            # Screen recording to GIF (ffmpeg)
  handoff/        # Session continuity (SBAR-style)
  qmd/            # Reference repo manager (BM25/vector search)
  polish/         # Full codebase polish (parallel agents)
  teams/          # Agent team orchestration (parallel sessions)
  techdebt/       # Tech debt detection
```

Each plugin has:
- `.claude-plugin/plugin.json` — manifest (name, version, description, dependencies)
- `skills/` — skill implementations (instructions + bash scripts)
- `README.md` — plugin-specific docs

## Conventions

- Conventional commits: `type(scope): description` — scope is the plugin name
- Plugin versions track marketplace version in `marketplace.json`
- Skills are bash-based CLI wrappers with markdown instruction files
- No npm/node — pure shell + Claude Code plugin system
- Plugins are independent — no cross-plugin dependencies

## Agent Team Guidelines

When working as a team on this repo:

- **One plugin per teammate** — each teammate owns a plugin directory to avoid file conflicts
- **Shared files** (marketplace.json, README.md, CHANGELOG.md) are lead-only — teammates report changes needed, lead applies them
- **Test skills** by reading the instruction files and verifying bash scripts have correct syntax
- **Plugin changes** require updating both the plugin's `plugin.json` and the root `marketplace.json` if metadata changed

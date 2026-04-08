# qmd plugin

A Claude Code plugin that wraps [qmd](https://github.com/tobi/qmd) — an on-device hybrid search engine for markdown and source code — and teaches Claude how to use it.

What you get:

- An MCP server (`mcp__qmd__query/get/multi_get/status`) auto-wired via `.mcp.json` so Claude can search your indexed reference repos as native tools.
- A search SKILL that loads automatically when Claude needs to look something up in an indexed collection. It encodes the decisions Claude needs to make: when to use qmd vs Grep, how to compose typed sub-queries, when to pass `intent`, when to delegate to a subagent.
- An `/qmd:add` SKILL that adds a reference collection to qmd. Accepts a GitHub URL, an `owner/repo` shorthand, OR a local directory path. Auto-detects file types, sets up `ignore:` globs, indexes with `--chunk-strategy auto`, embeds, and verifies — all in a forked subagent so it doesn't pollute your main context.
- 17 slash commands for the operations you actually run by hand:
  - **Indexing & maintenance**: `/qmd:status`, `/qmd:update`, `/qmd:embed`, `/qmd:cleanup`, `/qmd:pull`, `/qmd:bench`, `/qmd:mcp`
  - **Collection management**: `/qmd:remove`, `/qmd:rename`, `/qmd:collection-show`, `/qmd:collection-update-cmd`, `/qmd:collection-include`, `/qmd:collection-exclude`, `/qmd:context`
  - **CLI fallbacks** (when MCP is down): `/qmd:search`, `/qmd:query`, `/qmd:get`

The plugin does NOT mirror upstream qmd documentation. The MCP server already injects its own tool descriptions and dynamic instructions into the model's context. The plugin's job is to add the Claude-specific decision logic on top.

## Quick start

```bash
# Install qmd itself
npm install -g @tobilu/qmd
qmd pull                                    # Pre-download GGUF models (~2 GB)

# Install the plugin (user scope; this is a personal reference library)
/plugin install qmd@ramonclaudio-skills

# Add a reference repo from GitHub
/qmd:add vercel/next.js
/qmd:add https://github.com/tobi/qmd
/qmd:add rust-lang/rust --full              # Full clone, not shallow
/qmd:add facebook/react --defer-embed       # Skip embed; batch later

# Add a LOCAL directory (notes, work repo, anything on disk)
/qmd:add ~/Documents/notes
/qmd:add ~/work/internal-docs --name internal-docs
/qmd:add .                                   # cwd

# Embed deferred repos
/qmd:update

# Then search in any conversation
"How does Next.js App Router validate auth in middleware?"
# Claude calls mcp__qmd__query automatically with intent + typed sub-queries
```

## What's in the plugin

```
plugins/qmd/
├── .claude-plugin/plugin.json
├── .mcp.json                     # auto-wires the qmd MCP server
├── README.md                     # this file
├── CHANGELOG.md
├── skills/
│   ├── add/
│   │   ├── SKILL.md              # /qmd:add — clone + index workflow
│   │   └── examples.md
│   └── search/
│       ├── SKILL.md              # decision rules for searching qmd
│       └── references/
│           ├── examples.md       # worked query examples
│           └── pipeline.md       # pipeline internals (chunking, RRF, blending)
├── commands/
│   ├── status.md                 # /qmd:status               — index health
│   ├── update.md                 # /qmd:update               — pull + re-index + embed
│   ├── embed.md                  # /qmd:embed                — manual embed
│   ├── cleanup.md                # /qmd:cleanup              — clear caches + vacuum
│   ├── bench.md                  # /qmd:bench                — search quality benchmark
│   ├── pull.md                   # /qmd:pull                 — pre-download models
│   ├── mcp.md                    # /qmd:mcp                  — manage MCP daemon
│   ├── remove.md                 # /qmd:remove               — drop a collection
│   ├── rename.md                 # /qmd:rename               — rename a collection
│   ├── collection-show.md        # /qmd:collection-show      — inspect single collection
│   ├── collection-update-cmd.md  # /qmd:collection-update-cmd — set/change pre-update shell command
│   ├── collection-include.md     # /qmd:collection-include   — include in default queries
│   ├── collection-exclude.md     # /qmd:collection-exclude   — exclude from default queries
│   ├── context.md                # /qmd:context              — manage collection contexts
│   ├── search.md                 # /qmd:search               — BM25 fallback
│   ├── query.md                  # /qmd:query                — hybrid fallback
│   └── get.md                    # /qmd:get                  — retrieve fallback
└── templates/
    └── index.yml                 # example collection config
```

## Architecture

**Reads** go through MCP. The plugin's `.mcp.json` registers the qmd stdio server and Claude calls `mcp__qmd__query`, `mcp__qmd__get`, `mcp__qmd__multi_get`, `mcp__qmd__status` directly. The search SKILL is preloaded so Claude knows when and how to compose queries.

**Writes** go through skills and slash commands. `/qmd:add` is a forked subagent (its own context, its own clean exit). The other 10 commands are simple bash wrappers around `qmd` subcommands that Claude monitors and reports on.

## Why slash commands AND an MCP server

- **MCP** is for the read path (search and retrieval). Claude calls these tools automatically as part of normal conversation.
- **Slash commands** are for write/maintenance operations the user wants to trigger explicitly: re-embedding, cleanup, benchmarking, daemon management. They run in your main session so Claude can read the output and respond.
- **The `add` SKILL** is a forked subagent so the multi-step clone+detect+index+embed workflow doesn't bloat your conversation context.

The plugin deliberately does NOT ship slash commands for every qmd subcommand. If you want to manage contexts, list collections, or rename things, type the `qmd` CLI directly — slash commands only exist where Claude's interpretation of the output adds value.

## Common workflows

**Add a few new refs in batch**

```bash
/qmd:add vercel/next.js --defer-embed
/qmd:add facebook/react --defer-embed
/qmd:add sveltejs/svelte --defer-embed
/qmd:update                       # pulls + re-indexes + embeds in one shot
```

**Force re-embed after a model change**

```bash
/qmd:embed --force
```

**Recover from a broken index**

```bash
/qmd:cleanup
/qmd:embed --force
/qmd:status
```

**Mute a noisy collection from default searches**

```bash
/qmd:collection-exclude sessions     # mark includeByDefault: false
# Now /qmd:status shows [excluded] tag
# Search it explicitly when you do want it:
qmd query "..." -c sessions
/qmd:collection-include sessions     # bring it back
```

**Inspect or update a collection's config**

```bash
/qmd:collection-show next.js                                    # path, pattern, ignore, update-cmd
/qmd:collection-update-cmd next.js 'git -C ~/Developer/refs/next.js pull --rebase --ff-only'
/qmd:rename old-name new-name                                   # rename a collection
/qmd:context add qmd://next.js/docs/api "Stable App Router API reference"
/qmd:context list                                                # all contexts grouped by collection
```

**Check whether MCP search is healthy**

```bash
/qmd:status
# or, if MCP tools are missing entirely from the tool list:
/mcp
```

**Compose a sharper query yourself when auto-routing misses**

In a conversation, you can ask Claude to use a specific shape:

> Search the convex-src collection for advisory locking. Use lex `"advisory lock"` and a hyde sub-query. Pass intent "Postgres advisory locks for cron leader election".

The search SKILL teaches Claude to call `mcp__qmd__query` with that exact structure.

## After updating the plugin

Run `/reload-plugins` to pick up changes without restarting Claude Code. Skill, command, and MCP server changes all reload.

## Conflict warning: don't run `qmd skill install`

Upstream qmd 2.0.1+ ships its own packaged skill that writes to `~/.agents/skills/qmd` with an optional symlink at `~/.claude/skills/qmd`. This plugin already provides a richer search SKILL. Installing both creates a name collision and Claude Code may load the wrong one.

If you want to compare, run `qmd skill show` to print the upstream version to stdout without writing it to disk.

## Requirements

- `qmd` >= **2.1.0**: `npm install -g @tobilu/qmd` or `bun install -g @tobilu/qmd`
- Node.js >= 22 or Bun runtime
- `git`
- macOS: Homebrew SQLite (`brew install sqlite`) for extension support
- ~2 GB disk for GGUF models

## Version

1.8.0 — wraps qmd CLI 2.1.0+. Plugin and tool versions are independent.

# QMD Plugin

Reference repo manager. Clone GitHub repos, index with [QMD](https://github.com/tobi/qmd), search with BM25/vector/hybrid — all on-device.

Repos persist in `~/Developer/refs/`. Incremental updates only re-embed what changed.

## Architecture

**Reads** go through MCP — the plugin declares a `.mcp.json` that exposes `qmd_search`, `qmd_vsearch`, `qmd_query`, `qmd_get`, `qmd_multi_get`, and `qmd_status` as native Claude tools. No bash spawning. A companion **search guide skill** loads automatically when Claude is about to search, teaching it which modality to use (keyword, semantic, or hybrid).

**Writes** go through skills and commands:

| Command | What it does |
|---------|-------------|
| `/qmd:add <url>` | Clone + auto-detect + index + embed (8-step orchestration, runs in isolated fork) |
| `/qmd:update` | Pull all repos, re-index, re-embed |
| `/qmd:remove <name>` | Remove collection from index (keeps repo) |
| `/qmd:cleanup` | Clear caches, vacuum database |
| `/qmd:status` | Show index status via Bash (fallback when MCP is down) |

## Usage

```bash
/qmd:add vercel/next.js --dry-run               # Preview what would happen
/qmd:add https://github.com/tobi/qmd            # Clone + index + embed
/qmd:add vercel/next.js --mask "**/*.{md,mdx}"  # Shorthand + custom mask
/qmd:add rust-lang/rust --full                   # Full clone (default is shallow)
/qmd:update                                      # Pull all repos, re-embed
/qmd:remove old-repo                             # Remove from index
/qmd:cleanup                                     # Clear caches, vacuum DB
/qmd:status                                      # Index status (Bash, no MCP needed)
```

### Batch workflow

Use `--defer-embed` to add multiple repos without embedding after each one, then embed once:

```bash
/qmd:add vercel/next.js --defer-embed
/qmd:add facebook/react --defer-embed
/qmd:add sveltejs/svelte --defer-embed
/qmd:update
```

Once MCP is active, Claude uses `qmd_search`, `qmd_query`, `qmd_get` etc. directly as tools — no slash command needed for reads.

### Composability

After MCP search returns a path, use `@` references to pull the full file into context:

```
> search for "middleware" in the next.js collection
# Claude uses qmd_query, returns paths
> explain @~/Developer/refs/next.js/packages/next/src/server/router.ts
```

The `qmd` CLI also works standalone for headless pipelines:

```bash
qmd search "auth pattern" | claude -p "summarize these results"
```

## How Add Works

1. Parses URL or `owner/repo` shorthand
2. Shallow clones to `~/Developer/refs/<name>` (or pulls if exists). Use `--full` for complete history.
3. Auto-detects file types (TypeScript, Rust, Go, Python, Swift) to build glob mask. Merges masks for polyglot repos. Fails explicitly if no type detected — use `--mask` to override. *(`--dry-run` stops here — prints the plan and exits)*
4. Adds QMD collection with detected mask
5. Sets `update: "git pull --ff-only"` via CLI (falls back to config edit)
6. Extracts collection context from README (first meaningful paragraph)
7. Runs incremental embed (skipped with `--defer-embed`)
8. Verifies with `qmd status`

The add skill runs with `context: fork` — it executes in an isolated context and returns a summary. Your main conversation stays clean.

The skill is idempotent. If it fails partway, re-run with the same arguments — it pulls instead of re-cloning and removes/re-adds existing collections.

## Context Cost

**MCP tools:** With tool search enabled (the default), Claude defers MCP tool definitions until needed rather than loading all 6 into every request. The qmd MCP server process still runs, but context cost is low until you actually search.

**Skills:** The add, update, remove, cleanup, and status commands use `disable-model-invocation: true` — zero context cost until you invoke them. The search guide skill is model-invocable (Claude sees its one-line description each request) so it can auto-load when relevant.

**MCP recovery:** MCP connections can fail silently mid-session. If search tools stop responding, run `/qmd:status` (Bash fallback) or `/mcp` to check the server connection.

## Installation

Install at **user scope** (recommended — this is a personal reference library):

```bash
/plugin install qmd@ramonclaudio-skills
```

Project scope would push it to all collaborators and add MCP context cost to their sessions.

## Requirements

- `qmd` ([github.com/tobi/qmd](https://github.com/tobi/qmd)) installed globally
- `git`
- ~2GB disk for GGUF models (auto-downloaded on first embed)

## Version

1.0.0

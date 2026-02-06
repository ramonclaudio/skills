# QMD Plugin

Reference repo manager. Clone GitHub repos, index with [QMD](https://github.com/tobi/qmd), search with BM25/vector/hybrid — all on-device.

Repos persist in `~/Developer/refs/`. Incremental updates only re-embed what changed.

## Architecture

Reads go through MCP. The plugin declares a `.mcp.json` that exposes `qmd_search`, `qmd_vsearch`, `qmd_query`, `qmd_get`, `qmd_multi_get`, and `qmd_status` as native Claude tools. No bash spawning. A search guide skill loads automatically before searches so the model knows when to use keyword vs semantic vs hybrid.

Writes go through skills and commands:

| Command | What it does |
|---------|-------------|
| `/qmd:add <url>` | Clone + auto-detect + index + embed (runs in isolated fork) |
| `/qmd:update` | Pull all repos, re-index, re-embed |
| `/qmd:remove <name>` | Remove collection from index (keeps repo) |
| `/qmd:rename <old> <new>` | Rename a collection |
| `/qmd:list [collection]` | List collections or files within a collection |
| `/qmd:context <sub>` | Manage contexts (list, add, rm, check) |
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
/qmd:rename old-name new-name                    # Rename a collection
/qmd:list                                        # List all collections
/qmd:list next.js/packages                       # List files under a path
/qmd:context list                                # Show all configured contexts
/qmd:context check                               # Find collections missing context
/qmd:context rm qmd://old-repo                   # Remove a stale context
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

```text
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

The add skill runs with `context: fork`, so it executes in isolation and returns a summary without polluting your conversation.

The skill is idempotent. If it fails partway, re-run with the same arguments — it pulls instead of re-cloning and removes/re-adds existing collections.

## Context Cost

With tool search enabled (the default), Claude defers MCP tool definitions until needed rather than loading all 6 into every request. The qmd MCP server process still runs, but context cost is low until you actually search.

All commands and skills are model-invocable — Claude can invoke them autonomously when relevant. The search guide skill auto-loads when Claude needs to search indexed references.

MCP connections can fail silently mid-session. If search tools stop responding, run `/qmd:status` (Bash fallback) or `/mcp` to check the server connection.

## Installation

Install at **user scope** (recommended — this is a personal reference library):

```bash
/plugin install qmd@ramonclaudio-skills
```

Project scope would push it to all collaborators and add MCP context cost to their sessions.

## How Update Works

The add skill sets `update: "git pull --ff-only"` in each collection's config (`~/.config/qmd/index.yml`). When `/qmd:update` runs `qmd update`, it executes each collection's update command before re-indexing. Then `qmd embed` generates embeddings for new/changed content.

To force re-embed everything (e.g., after a model update or corrupted embeddings):

```bash
qmd embed -f
```

## Named Indexes

QMD supports separate indexes via `--index <name>`. Config lives at `~/.config/qmd/<name>.yml`, database at `~/.cache/qmd/<name>.sqlite`. Useful for keeping work/personal refs isolated:

```bash
qmd --index work collection add ~/work/docs --name internal-docs
qmd --index work search "deployment process"
```

## MCP Resources and Prompts

Beyond the 6 search/retrieval tools, the MCP server also exposes:

- **Resource template** `qmd://{+path}` — MCP clients can read documents directly via URI without using the `get` tool.
- **Prompt** `query` — A search strategy guide that MCP clients supporting prompts receive automatically.

## GGUF Models

QMD uses three local GGUF models (auto-downloaded on first use via node-llama-cpp):

| Model | Purpose | Size |
|-------|---------|------|
| `embeddinggemma-300M-Q8_0` | Vector embeddings (768 dimensions) | ~300MB |
| `qwen3-reranker-0.6b-q8_0` | Cross-encoder re-ranking | ~640MB |
| `qmd-query-expansion-1.7B-q4_k_m` | Query expansion (fine-tuned) | ~1.1GB |

Models are cached in `~/.cache/qmd/models/`. The index database lives at `~/.cache/qmd/index.sqlite`, config at `~/.config/qmd/index.yml`.

## Requirements

- `qmd` ([github.com/tobi/qmd](https://github.com/tobi/qmd)) installed globally
- `git`
- ~2GB disk for GGUF models (auto-downloaded on first embed)

## Version

1.0.0

# QMD Plugin

Reference repo manager. Clone GitHub repos, index with [QMD](https://github.com/tobi/qmd), search with BM25/vector/hybrid — all on-device.

Cloned repos default to `~/Developer/refs/` but any path works — QMD indexes whatever directory you point it at. Incremental updates only re-embed what changed.

## Architecture

Reads go through MCP. The plugin declares a `.mcp.json` that exposes `query`, `get`, `multi_get`, and `status` as native Claude tools. No bash spawning. The `query` tool accepts query documents — structured multi-line queries with typed sub-queries (`lex:`, `vec:`, `hyde:`, `expand:`). A search guide skill loads automatically before searches so the model knows how to compose effective queries.

Writes go through skills and commands:

| Command | What it does |
|---------|-------------|
| `/qmd:add <url>` | Clone + auto-detect + index + embed (runs in isolated fork) |
| `/qmd:update` | Pull all repos, re-index, re-embed |
| `/qmd:remove <name>` | Remove collection from index (keeps repo) |
| `/qmd:rename <old> <new>` | Rename a collection |
| `/qmd:list [collection]` | List collections or files within a collection |
| `/qmd:context <sub>` | Manage contexts (list, add, rm) |
| `/qmd:cleanup` | Clear caches, vacuum database |
| `/qmd:status` | Show index status via Bash (fallback when MCP is down) |
| `/qmd:embed` | Generate or refresh vector embeddings |
| `/qmd:pull` | Download or verify GGUF models from HuggingFace |
| `/qmd:get` | Retrieve document by path or docid (CLI fallback) |
| `/qmd:multi-get` | Retrieve multiple documents by glob or list (CLI fallback) |
| `/qmd:search` | BM25 keyword search (CLI fallback) |
| `/qmd:vsearch` | Vector/semantic search (CLI fallback) |
| `/qmd:query` | Hybrid deep search with reranking (CLI fallback) |
| `/qmd:collection-add <path>` | Add a local directory as a collection |
| `/qmd:collection-list` | List all collections with metadata |
| `/qmd:collection-show <name>` | Show collection details |
| `/qmd:collection-update-cmd <name> '<cmd>'` | Set pre-update shell command |
| `/qmd:collection-include <name>` | Include collection in default queries |
| `/qmd:collection-exclude <name>` | Exclude collection from default queries |
| `/qmd:mcp` | Start, stop, or manage MCP server daemon |

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
/qmd:context rm qmd://old-repo                   # Remove a stale context
/qmd:cleanup                                     # Clear caches, vacuum DB
/qmd:status                                      # Index status (Bash, no MCP needed)
/qmd:embed                                       # Embed documents needing vectors
/qmd:embed -f                                    # Force re-embed everything
/qmd:pull                                        # Download/verify all 3 models
/qmd:pull --refresh                              # Re-download even if cached
/qmd:get #abc123                                 # Get document by docid
/qmd:get next.js/README.md                       # Get by collection path
/qmd:mcp start                                   # Start MCP daemon (HTTP background)
/qmd:mcp stop                                    # Stop MCP daemon
```

### Batch workflow

Use `--defer-embed` to add multiple repos without embedding after each one, then embed once:

```bash
/qmd:add vercel/next.js --defer-embed
/qmd:add facebook/react --defer-embed
/qmd:add sveltejs/svelte --defer-embed
/qmd:update
```

Once MCP is active, Claude uses `query`, `get` etc. directly as tools — no slash command needed for reads.

### Composability

After MCP search returns a path, use `@` references to pull the full file into context:

```text
> search for "middleware" in the next.js collection
# Claude uses query tool, returns paths
> explain @~/Developer/refs/next.js/packages/next/src/server/router.ts
```

The `qmd` CLI also works standalone for headless pipelines:

```bash
qmd search "auth pattern" | claude -p "summarize these results"
```

## How Add Works

1. Parses URL or `owner/repo` shorthand
2. Shallow clones to `$REFS/<name>` (default `~/Developer/refs/`, override with `--dest`; pulls if exists). Use `--full` for complete history.
3. Auto-detects file types (TypeScript, Rust, Go, Python, Swift) to build glob mask. Merges masks for polyglot repos. Fails explicitly if no type detected — use `--mask` to override. *(`--dry-run` stops here — prints the plan and exits)*
4. Adds QMD collection with detected mask
5. Sets update command via `qmd collection update-cmd`
6. Extracts collection context from README (first meaningful paragraph)
7. Runs incremental embed (skipped with `--defer-embed`)
8. Verifies with `qmd status`

The add skill runs with `context: fork`, so it executes in isolation and returns a summary without polluting your conversation.

The skill is idempotent. If it fails partway, re-run with the same arguments — it pulls instead of re-cloning and removes/re-adds existing collections.

## Context Cost

With tool search enabled (the default), Claude defers MCP tool definitions until needed rather than loading all 4 into every request. The qmd MCP server process still runs, but context cost is low until you actually search.

All commands and skills are model-invocable. Claude can invoke them on its own when relevant. The search guide skill auto-loads when Claude needs to search indexed references.

MCP connections can fail silently mid-session. If search tools stop responding, run `/qmd:status` (Bash fallback) or `/mcp` to check the server connection.

## Installation

Install at **user scope** (recommended — this is a personal reference library):

```bash
/plugin install qmd@ramonclaudio-skills
```

Project scope would push it to all collaborators and add MCP context cost to their sessions.

## How Update Works

The add skill sets `update: "git -C <path> pull --ff-only"` in each collection's config (`${XDG_CONFIG_HOME:-~/.config}/qmd/index.yml`). When `/qmd:update` runs `qmd update`, it clears the LLM cache, then executes each collection's update command before re-indexing. Then `qmd embed` generates embeddings for new/changed content.

`qmd update` always processes ALL collections — there is no single-collection argument. If any collection's update command fails, the process exits immediately (remaining collections are skipped).

To force re-embed everything (e.g., after a model update or corrupted embeddings):

```bash
qmd embed -f
```

## Named Indexes

QMD supports separate indexes via `--index <name>`. Config lives at `${XDG_CONFIG_HOME:-~/.config}/qmd/<name>.yml`, database at `${XDG_CACHE_HOME:-~/.cache}/qmd/<name>.sqlite`. Useful for keeping work/personal refs isolated:

```bash
qmd --index work collection add ~/work/docs --name internal-docs
qmd --index work search "deployment process"
```

## MCP Resources

The MCP server generates dynamic instructions at startup from actual index state. LLMs see collection names, document counts, and content descriptions without a tool call.

The MCP server also exposes a resource template `qmd://{+path}` so MCP clients can read documents by URI without the `get` tool.

## GGUF Models

QMD uses three local GGUF models (auto-downloaded on first use via node-llama-cpp, or manually via `qmd pull`):

| Model | Purpose | Size |
|-------|---------|------|
| `embeddinggemma-300M` (Q8_0) | Vector embeddings | ~300MB |
| `qwen3-reranker-0.6b` (Q8_0) | Cross-encoder re-ranking | ~640MB |
| `qmd-query-expansion-1.7B` (Q4_K_M, GRPO fine-tuned) | Query expansion (lex/vec/hyde) | ~1.1GB |

Models are cached in `~/.cache/qmd/models/`. The index database lives at `${XDG_CACHE_HOME:-~/.cache}/qmd/index.sqlite`, config at `${XDG_CONFIG_HOME:-~/.config}/qmd/index.yml`.

GPU acceleration is auto-detected (Metal on macOS, CUDA on Linux/Windows, Vulkan as fallback). Parallel GPU contexts can do up to 2.7x faster reranking on multi-core machines.

Documents are chunked at scored markdown breakpoints. The chunker prefers splitting at headers, then code blocks, then paragraph boundaries, then list items, rather than mid-sentence. Code fences are never split. 900 tokens per chunk with 15% overlap.

## MCP HTTP Transport

For a shared, long-lived server that keeps models warm in VRAM between queries:

```bash
qmd mcp --http --daemon           # Start background daemon on port 8181
qmd mcp stop                      # Stop the daemon
qmd status                        # Shows "MCP: running (PID ...)" when active
```

The HTTP server exposes `POST /mcp` (Streamable HTTP) and `GET /health` (liveness). Point any MCP client at `http://localhost:8181/mcp`.

## Reference Documentation

Reference docs, loaded when relevant:

| Reference | Content |
|-----------|---------|
| `references/cli-reference.md` | All commands, flags, and options |
| `references/architecture.md` | SQLite schema, content-addressable storage, hybrid search pipeline |
| `references/models.md` | 3 GGUF models: embedding, reranking, query expansion |
| `references/MCP-SETUP.md` | MCP server configuration for Claude Code and Claude Desktop |
| `references/example-index.yml` | Example collection configuration with contexts |
| `skills/search/references/pipeline.md` | Hybrid search pipeline internals (RRF, blending, chunking) |

## CLI Extras

- `qmd --version` / `qmd -v` — show version with git commit hash (e.g. `1.0.8 (abc1234)`)
- `qmd --help` — full command reference (note: `--pull` appears here but is a dead flag)
- `qmd deep-search` — alias for `qmd query`
- `qmd vector-search` — alias for `qmd vsearch`
- `qmd collection rm` — alias for `qmd collection remove`
- `qmd collection mv` — alias for `qmd collection rename`
- `qmd context remove` — alias for `qmd context rm`
- Multiple collection filters: `qmd search "query" -c react -c next.js`
- `--line-numbers` — add line numbers to search/get output
- Output formats: `--files`, `--json`, `--csv`, `--md`, `--xml`

## Requirements

- `qmd` ([github.com/tobi/qmd](https://github.com/tobi/qmd)) — `npm install -g @tobilu/qmd` or `bun install -g @tobilu/qmd`
- Node.js 22+ or Bun runtime
- `git`
- macOS: Homebrew SQLite (`brew install sqlite`) for extension support
- ~2GB disk for GGUF models (auto-downloaded on first embed, or `qmd pull`)

## Version

1.4.0

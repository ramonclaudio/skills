# QMD CLI Reference

Complete command-line reference for QMD search engine.

## Global Flags

Available on all commands:

| Flag | Purpose |
|------|---------|
| `--index <name>` | Use custom index (DB: `~/.cache/qmd/<name>.sqlite`, config: `~/.config/qmd/<name>.yml`) |
| `--context <text>` | Dead flag (defined in parser, never read) |
| `-h`, `--help` | Show command help |
| `-v`, `--version` | Show version (includes git commit hash when available, e.g. `1.0.8 (abc1234)`) |

## Search Commands

All search commands share these universal flags:

| Flag | Default | Purpose |
|------|---------|---------|
| `-n <num>` | 5 (CLI), 20 (JSON/files) | Maximum results |
| `--all` | - | Unlimited results (limit=100000) |
| `--min-score <num>` | 0 (search/query), 0.3 (vsearch) | Minimum relevance score (0-1) |
| `--full` | - | Return full document content, not snippets |
| `--line-numbers` | - | Include line numbers in output |
| `-c <name>`, `--collection <name>` | - | Filter to specific collection (repeatable) |
| `--json` | - | JSON output format |
| `--csv` | - | CSV output format |
| `--md` | - | Markdown table format |
| `--xml` | - | XML output format |
| `--files` | - | File paths only |

### qmd search

BM25 keyword search. Fast FTS5 with porter+unicode61 tokenizer. No LLM calls.

```bash
qmd search "exact term or phrase"
qmd search "function handleAuth" -c next.js -n 10
qmd search "ECONNREFUSED" --json --min-score 0.5
```

**Score normalization:** `|x| / (1 + |x|)` maps raw BM25 scores to 0-1 range (e.g., strong(-10) → 0.91, medium(-2) → 0.67, weak(-0.5) → 0.33).

### qmd vsearch

Vector search with query expansion and RRF fusion. No reranking step.

```bash
qmd vsearch "authentication flow"
qmd vsearch "state management pattern" -c react -n 10
```

**Aliases:** `vector-search`

**Default min-score:** 0.3

Uses query expansion internally (vec/hyde types only, no lex).

### qmd query

Full hybrid pipeline: BM25 probe → conditional expansion → parallel FTS+vector → RRF fusion (k=60) → top-40 → LLM reranking → position-aware blending → dedup.

```bash
qmd query "how does routing work"
qmd query "middleware authentication" -c next.js --all
```

**Query document format:** Supports typed sub-queries for fine-grained control. Pass multi-line input with explicit query types:

```bash
# Multi-line query document with typed sub-queries
qmd query $'lex: "authentication middleware"\nvec: how requests are authenticated\nhyde: The server validates the JWT token in the Authorization header'

# Lex syntax: quoted phrases for exact match, -negation for exclusion
qmd query $'lex: "rate limit" -redis\nvec: request throttling strategy'

# Single type
qmd query $'vec: state management patterns in React'
```

**Sub-query types:**
- `lex:`: BM25 keyword search. Supports `"phrase"` for exact match (bypasses prefix matching) and `-term` for negation.
- `vec:`: Vector similarity search.
- `hyde:`: Hypothetical document embedding (vector search with synthetic answer).
- `expand:`: Auto-expand into multiple sub-queries.

**Aliases:** `deep-search`

Slowest but most accurate. ~10s latency (first query slower while models load).

## Retrieval Commands

### qmd get

Retrieve a document by path or docid.

```bash
qmd get next.js/docs/api-reference.md
qmd get #abc123
qmd get docs/setup.md:100          # Start at line 100
qmd get path/to/file.md --from 50 -l 100 --line-numbers
```

| Flag | Purpose |
|------|---------|
| `--from <N>` | Start from line N (1-indexed) |
| `-l <N>` | Max lines to return |
| `--line-numbers` | Add line numbers to output |

**Path resolution order:**
1. Docid format (`#abc123` = first 6 chars of SHA-256 hash)
2. Virtual paths (`qmd://collection/path`)
3. Collection-prefixed paths (`collection/path/file.md`)
4. Filesystem absolute paths
5. Filesystem relative paths from cwd
6. Suffix match fallback (last resort)

**Line offset syntax:** Append `:line` to path (e.g., `docs/api.md:100`)

### qmd multi-get

Retrieve multiple documents by glob pattern or comma-separated list.

```bash
qmd multi-get "docs/*.md"
qmd multi-get "#abc123, #def456, #789abc"
qmd multi-get "next.js/packages/**/*.ts" -l 50 --max-bytes 20480
```

| Flag | Default | Purpose |
|------|---------|---------|
| `-l <N>` | - | Max lines per file |
| `--max-bytes <N>` | 10240 (10KB) | Skip files larger than N bytes |
| `--line-numbers` | - | Add line numbers |

Plus all output format flags (`--json`, `--csv`, etc.).

**Pattern formats:**
- Glob: `docs/*.md`, `**/*.ts`
- Comma-separated: `#abc, #def, collection/path`
- Docids: `#abc123, #def456`

## Index Management

### qmd ls

List collections or files in a collection.

```bash
qmd ls                      # List all collections
qmd ls next.js              # List files in next.js collection
qmd ls next.js/docs         # List files under next.js/docs
```

Output format: `ls -l` style (size, date, path). Both `qmd ls` and `qmd collection list` read from YAML + database. They differ in output format, not data source.

### qmd status

Show index health, collections, MCP status, GPU info, models.

```bash
qmd status
```

Returns:
- Total documents
- Collections with document counts
- Pending embeddings
- MCP server status (stdio/HTTP/daemon)
- GPU detection (Metal/CUDA/Vulkan/CPU)
- Loaded models

### qmd embed

Generate vector embeddings for all documents.

```bash
qmd embed                   # Embed pending documents
qmd embed -f                # Force re-embed all (clears existing)
qmd embed --force
```

| Flag | Purpose |
|------|---------|
| `-f`, `--force` | Clear all embeddings and re-embed from scratch |

First run auto-downloads 3 GGUF models (~2GB). Uses 900 tokens/chunk with 15% overlap (135 tokens).

### qmd update

Re-index all collections. Always updates ALL collections. No single-collection argument.

```bash
qmd update                  # Run update commands + re-index all collections
```

Pipeline:
1. Clears entire LLM cache before starting
2. For each collection: runs configured `update` command (e.g., `git pull`), then re-indexes
3. If any update command exits non-zero, `qmd update` exits immediately (remaining collections skipped)

Update commands are defined per collection in `~/.config/qmd/index.yml` (e.g., `update: "git -C ~/Developer/refs/next.js pull --ff-only"`). If a collection has no `update` field, only re-indexing runs.

Note: `--pull` appears in `qmd --help` but is a dead flag. Defined in the CLI parser but never read (`values.pull` has zero references). Update commands from YAML always run regardless.

### qmd pull

Download and verify GGUF models.

```bash
qmd pull                    # Download missing models
qmd pull --refresh          # Re-check ETag staleness
```

| Flag | Purpose |
|------|---------|
| `--refresh` | Force ETag check, re-download if remote changed |

Models cached in `~/.cache/qmd/models/`.

### qmd cleanup

Clear caches, remove orphaned data, vacuum database.

```bash
qmd cleanup
```

Operations:
1. Clear entire LLM cache (all entries deleted)
2. Remove orphaned embedding chunks (vectors with no active document)
3. Remove inactive document records (soft-deleted, `active = 0`)
4. Vacuum SQLite database to reclaim disk space

## MCP Server

### qmd mcp

Start MCP server (Model Context Protocol).

```bash
qmd mcp                             # stdio transport (default)
qmd mcp --http                      # HTTP server on :8181
qmd mcp --http --port 8080          # Custom port
qmd mcp --http --daemon             # Background daemon, PID file
qmd mcp stop                        # Stop daemon via PID file
```

| Flag | Purpose |
|------|---------|
| `--http` | HTTP transport (vs stdio) |
| `--port <N>` | HTTP port (default: 8181) |
| `--daemon` | Run in background (HTTP only) |

**stdio transport:** For Claude Code, Claude Desktop. Standard input/output communication.

**HTTP transport:**
- Endpoint: `POST /mcp` (JSON mode, no SSE streaming)
- Health check: `GET /health`
- PID file: `~/.cache/qmd/mcp.pid`
- Keeps models loaded in VRAM between requests (~16s → ~10s latency)

**MCP tools:** MCP exposes a single `query` tool (replacing the previous `search`, `vector_search`, and `deep_search` tools). The HTTP endpoint is `/query` (`/search` is kept as a silent alias for backward compatibility). The `query` tool accepts a `collections` array parameter instead of a single `collection` string.

**MCP subcommand:**
- `qmd mcp stop`: Stop daemon via PID file

## Collection Management

### qmd collection add

Add a directory as a collection.

```bash
qmd collection add ~/Developer/refs/next.js --name next.js
qmd collection add ~/Documents/notes --name notes --mask "**/*.md"
```

| Flag | Purpose |
|------|---------|
| `--name <name>` | Collection name (optional, auto-generated from directory name if omitted) |
| `--mask <pattern>` | Glob pattern for file inclusion (default: `**/*.md`) |

**Default mask:** `**/*.md`

### qmd collection list

List all collections with metadata.

```bash
qmd collection list
```

Output columns: name, path, pattern, file count, last updated.

### qmd collection remove

Remove a collection from YAML and database.

```bash
qmd collection remove next.js
qmd collection rm next.js           # Alias
```

**Aliases:** `rm`

Removes from `~/.config/qmd/index.yml` and marks documents as inactive in DB (soft delete).

### qmd collection rename

Rename a collection.

```bash
qmd collection rename next.js nextjs
qmd collection mv next.js nextjs    # Alias
```

**Aliases:** `mv`

Updates YAML config and database records.

### qmd collection show

Display collection details (path, pattern, update command, context entries, includeByDefault).

```bash
qmd collection show next.js
```

### qmd collection update-cmd

Set the shell command to run before re-indexing a collection.

```bash
qmd collection update-cmd next.js 'git -C ~/Developer/refs/next.js pull --ff-only'
```

### qmd collection include

Include a collection in default queries (sets `includeByDefault: true`).

```bash
qmd collection include next.js
```

### qmd collection exclude

Exclude a collection from default queries (sets `includeByDefault: false`). The collection remains indexed but is skipped unless explicitly targeted with `-c`.

```bash
qmd collection exclude notes
```

## Context Management

### qmd context add

Add context hints for paths or collections.

```bash
qmd context add "Context for current directory"            # One-arg: uses cwd
qmd context add qmd://next.js/ "Next.js framework source code"
qmd context add qmd://next.js/docs "Official Next.js documentation"
qmd context add / "If you see a [[WikiWord]], search for it"
qmd context add docs/api.md "API reference for v2.0"
```

**One-arg form:** `qmd context add "text"`: no path argument, auto-detects collection from cwd.

**Path formats (two-arg form):**
- Virtual: `qmd://collection/path`
- Global: `/` (applies to all collections)
- Filesystem: absolute or relative paths

Context is hierarchical. All matching path prefixes are concatenated (global → root → specific), joined with `\n\n`.

### qmd context list

List all context entries grouped by collection.

```bash
qmd context list
```

### qmd context rm

Remove a context entry.

```bash
qmd context rm qmd://next.js/docs
qmd context remove qmd://next.js/docs    # Alias
```

**Aliases:** `remove`

## Output Formats

| Format | Flag | Example |
|--------|------|---------|
| Text | (default) | `qmd search "query"` |
| JSON | `--json` | `qmd search "query" --json` |
| CSV | `--csv` | `qmd search "query" --csv` |
| Markdown | `--md` | `qmd search "query" --md` |
| XML | `--xml` | `qmd search "query" --xml` |
| Files only | `--files` | `qmd search "query" --files` |

MCP tools return structured content via `structuredContent` field in addition to text.

## Score Interpretation

| Score Range | Meaning | Action |
|-------------|---------|--------|
| 0.8 - 1.0 | Highly relevant | Show to user |
| 0.5 - 0.8 | Moderately relevant | Include if few results |
| 0.2 - 0.5 | Somewhat relevant | Only if user wants more |
| 0.0 - 0.2 | Low relevance | Usually skip |

**BM25 normalization:** `|x| / (1 + |x|)` maps raw scores to 0-1 range.

## Named Indexes

Use `--index <name>` to separate work/personal collections:

```bash
qmd --index work search "deployment"
qmd --index personal search "journal"
qmd --index work collection add ~/work-repos/api --name api
```

**Paths:**
- DB: `~/.cache/qmd/<name>.sqlite`
- Config: `~/.config/qmd/<name>.yml`

Default index (no `--index` flag): `~/.cache/qmd/index.sqlite`, `~/.config/qmd/index.yml`

## Docid Format

Docids are the first 6 characters of the SHA-256 hash of document content.

```bash
qmd get #abc123
qmd get abc123              # Leading # is optional
qmd multi-get "#abc, #def, #123"
```

**Format:** `#` + 6 hex chars (e.g., `#abc123`). Leading `#` is optional in CLI usage.

Shown in search results, used for stable references across path changes.

## Path Resolution Rules

When `qmd get <path>` is called:

1. **Docid match:** `#abc123` → lookup by hash
2. **Virtual path:** `qmd://collection/path` → resolve to collection path
3. **Collection prefix:** `next.js/docs/api.md` → resolve to collection + path
4. **Absolute filesystem:** `/Users/name/file.md` → direct read
5. **Relative filesystem:** `docs/api.md` → resolve from cwd
6. **Suffix match:** `api.md` → find any path ending with `api.md` (fallback, may be ambiguous)

Use docids for stable references, collection-prefixed paths for clarity.

## Examples

```bash
# BM25 keyword search across all collections
qmd search "handleAuth" -n 10 --json

# Vector search in specific collection
qmd vsearch "authentication flow" -c next.js --min-score 0.4

# Hybrid search with unlimited results
qmd query "routing middleware" --all

# Retrieve document with line numbers
qmd get next.js/packages/next/src/server/web/adapter.ts --line-numbers

# Retrieve from line 100, max 50 lines
qmd get docs/api.md:100 -l 50

# Batch retrieve with glob
qmd multi-get "docs/*.md" --json

# Multiple collections
qmd search "useState" -c react -c next.js -n 20

# Named index
qmd --index work search "deployment" -c api

# Add collection with custom mask
qmd collection add ~/Developer/refs/rust-repo --name rust --mask "**/*.{rs,toml,md}"

# Add context
qmd context add qmd://rust/ "Rust standard library source"

# Embed after adding collections
qmd embed

# Re-index all collections (runs update commands from YAML first)
qmd update

# HTTP daemon mode
qmd mcp --http --daemon
curl http://localhost:8181/health
qmd mcp stop
```

# QMD MCP Server Setup

Detailed instructions for configuring QMD as an MCP (Model Context Protocol) server.

## Prerequisites

1. Install qmd globally:
   ```sh
   npm install -g @tobilu/qmd
   ```

2. Verify installation:
   ```sh
   qmd --help
   ```

3. Set up at least one collection:
   ```sh
   qmd collection add ~/Documents/notes --name notes
   qmd embed  # Generate vector embeddings
   ```

## Claude Code Configuration

Add to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "qmd": {
      "command": "qmd",
      "args": ["mcp"]
    }
  }
}
```

## Claude Desktop Configuration

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "qmd": {
      "command": "qmd",
      "args": ["mcp"]
    }
  }
}
```

## MCP Resources

The server registers documents as MCP Resources via `qmd://{+path}` URI template. MCP clients can read documents directly by URI without a tool call:

```
qmd://collection/path/to/file.md
```

**URI encoding:** Path segments are individually URL-encoded (preserves `/` separators, encodes special chars via `encodeURIComponent`).

**Resolution:** Exact match on `(collection, path)` first. If no match, falls back to suffix match (`LIKE %path`) — useful for partial paths.

**Response:** Markdown content with line numbers and context headers (if configured). Documents are discovered via search tools, then retrieved by URI.

## Available MCP Tools

Once configured, these tools become available:

### search
Fast BM25 keyword search.

**Parameters:**
- `query` (required): Search query — keywords or phrases to find
- `collection` (optional): Filter to a specific collection by name
- `limit` (optional): Maximum number of results (default: 10)
- `minScore` (optional): Minimum relevance score 0-1 (default: 0)

### vector_search
Semantic vector search for conceptual similarity. Finds relevant documents even when they use different words than the query.

**Parameters:**
- `query` (required): Natural language query — describe what you're looking for
- `collection` (optional): Filter to a specific collection by name
- `limit` (optional): Maximum number of results (default: 10)
- `minScore` (optional): Minimum relevance score 0-1 (default: 0.3)

### deep_search
Deep search with query expansion and LLM reranking. Auto-expands the query into variations, searches each by keyword and meaning, and reranks for top hits.

**Parameters:**
- `query` (required): Natural language query — describe what you're looking for
- `collection` (optional): Filter to a specific collection by name
- `limit` (optional): Maximum number of results (default: 10)
- `minScore` (optional): Minimum relevance score 0-1 (default: 0)

### get
Retrieve the full content of a document by file path or docid. Suggests similar files if not found.

**Parameters:**
- `file` (required): File path or docid from search results (e.g., `pages/meeting.md`, `#abc123`, or `pages/meeting.md:100` to start at line 100)
- `fromLine` (optional): Start from this line number (1-indexed)
- `maxLines` (optional): Maximum number of lines to return
- `lineNumbers` (optional): Add line numbers to output (default: false)

### multi_get
Retrieve multiple documents by glob pattern or comma-separated list. Skips files larger than maxBytes.

**Parameters:**
- `pattern` (required): Glob pattern or comma-separated list of file paths
- `maxLines` (optional): Maximum lines per file
- `maxBytes` (optional): Skip files larger than this (default: 10240 = 10KB)
- `lineNumbers` (optional): Add line numbers to output (default: false)

### status
Show the status of the QMD index: collections, document counts, and health information.

**Parameters:** None

## Troubleshooting

### MCP server not starting
- Ensure qmd is in your PATH: `which qmd`
- Try running `qmd mcp` manually to see errors
- Check that Node.js 22+ or Bun is installed: `node --version` / `bun --version`

### No results returned
- Verify collections exist: `qmd collection list`
- Check index status: `qmd status`
- Ensure embeddings are generated: `qmd embed`

### Slow searches
- For faster results, use `search` instead of `deep_search`
- The first search may be slow while models load (~2GB)
- Subsequent searches are much faster

## HTTP Transport

For a shared, long-lived server that avoids repeated model loading:

```sh
# Foreground
qmd mcp --http                    # localhost:8181
qmd mcp --http --port 8080        # custom port

# Background daemon
qmd mcp --http --daemon           # start, writes PID to ~/.cache/qmd/mcp.pid
qmd mcp stop                      # stop via PID file
```

The HTTP server exposes:
- `POST /mcp` — MCP Streamable HTTP (JSON mode, no SSE streaming)
- `GET /health` — liveness check with uptime

**Response formats:**

```bash
# Health check
curl http://localhost:8181/health
# → {"status":"ok","uptime":3600}

# MCP requests (JSON-RPC)
curl -X POST http://localhost:8181/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"search","arguments":{"query":"auth"}},"id":1}'
```

Point any MCP client at `http://localhost:8181/mcp` to connect. Models stay loaded in VRAM between requests.

## Named Indexes

Run a separate MCP server for a different index:

```sh
qmd --index work mcp          # stdio, "work" index
qmd --index work mcp --http   # HTTP, "work" index
```

Config: `~/.config/qmd/work.yml`, DB: `~/.cache/qmd/work.sqlite`.

## Dynamic Server Instructions

The MCP server generates instructions at startup from actual index state. Injected into the LLM's system prompt via the MCP `initialize` response — gives immediate context without a tool call. LLMs automatically receive:

- Total document count across all collections
- Global context (if configured)
- Per-collection names, document counts, and root context descriptions
- Capability gaps (e.g., "no embeddings — run `qmd embed`")
- Search tool escalation ladder with latency estimates:
  - `search` (~30ms) — keyword and exact phrase matching
  - `vector_search` (~2s) — meaning-based, finds adjacent concepts
  - `deep_search` (~10s) — auto-expands query, searches by keyword + meaning, reranks
- Retrieval workflow guidance (get, multi_get)
- Score interpretation tips (e.g., `minScore: 0.5` to filter low-confidence)

These instructions update every time the MCP server restarts.

## Choosing Between CLI and MCP

| Scenario | Recommendation |
|----------|---------------|
| MCP configured | Use MCP tools directly (`search`, `vector_search`, `deep_search`, `get`, `multi_get`, `status`) |
| No MCP | Use Bash with `qmd` commands |
| Complex pipelines | Bash may be more flexible |
| Simple lookups | MCP tools are cleaner |

# QMD MCP Server Setup

Detailed instructions for configuring QMD as an MCP (Model Context Protocol) server.

## Prerequisites

1. Install qmd globally:
   ```sh
   bun install -g https://github.com/tobi/qmd
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

## Available MCP Tools

Once configured, these tools become available:

### qmd_search
Fast BM25 keyword search.

**Parameters:**
- `query` (required): Search query — keywords or phrases to find
- `collection` (optional): Filter to a specific collection by name
- `limit` (optional): Maximum number of results (default: 10)
- `minScore` (optional): Minimum relevance score 0-1 (default: 0)

### qmd_vsearch
Semantic vector search for conceptual similarity.

**Parameters:**
- `query` (required): Natural language query — describe what you're looking for
- `collection` (optional): Filter to a specific collection by name
- `limit` (optional): Maximum number of results (default: 10)
- `minScore` (optional): Minimum relevance score 0-1 (default: 0.3)

### qmd_query
Hybrid search combining BM25, vector search, query expansion, and LLM re-ranking.

**Parameters:**
- `query` (required): Natural language query — describe what you're looking for
- `collection` (optional): Filter to a specific collection by name
- `limit` (optional): Maximum number of results (default: 10)
- `minScore` (optional): Minimum relevance score 0-1 (default: 0)

### qmd_get
Retrieve the full content of a document by file path or docid.

**Parameters:**
- `file` (required): File path or docid from search results (e.g., `pages/meeting.md`, `#abc123`, or `pages/meeting.md:100` to start at line 100)
- `fromLine` (optional): Start from this line number (1-indexed)
- `maxLines` (optional): Maximum number of lines to return
- `lineNumbers` (optional): Add line numbers to output (default: false)

### qmd_multi_get
Retrieve multiple documents by glob pattern or comma-separated list.

**Parameters:**
- `pattern` (required): Glob pattern or comma-separated list of file paths
- `maxLines` (optional): Maximum lines per file
- `maxBytes` (optional): Skip files larger than this (default: 10240 = 10KB)
- `lineNumbers` (optional): Add line numbers to output (default: false)

### qmd_status
Show the status of the QMD index: collections, document counts, and health information.

**Parameters:** None

## Troubleshooting

### MCP server not starting
- Ensure qmd is in your PATH: `which qmd`
- Try running `qmd mcp` manually to see errors
- Check that Bun is installed: `bun --version`

### No results returned
- Verify collections exist: `qmd collection list`
- Check index status: `qmd status`
- Ensure embeddings are generated: `qmd embed`

### Slow searches
- For faster results, use `qmd_search` instead of `qmd_query`
- The first search may be slow while models load (~3GB)
- Subsequent searches are much faster

## Choosing Between CLI and MCP

| Scenario | Recommendation |
|----------|---------------|
| MCP configured | Use `qmd_*` tools directly |
| No MCP | Use Bash with `qmd` commands |
| Complex pipelines | Bash may be more flexible |
| Simple lookups | MCP tools are cleaner |

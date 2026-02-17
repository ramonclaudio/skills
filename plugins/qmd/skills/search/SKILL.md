---
name: search
description: When to use search, vector_search, or deep_search across indexed reference collections.
user-invocable: false
agent: general-purpose
model: sonnet
---

# QMD Search Guide

## Current State
- **Collections:** !`qmd status 2>/dev/null | grep -c '^  ' || echo "0"`
- **Status:** !`qmd status 2>/dev/null | head -1 || echo "QMD not running"`

## When to use QMD

QMD searches **indexed collections** — external codebases, notes, docs you've added with `qmd collection add`. For files in the current working directory, use Grep and Glob instead. They're faster, cheaper on context, and more precise.

## Modality

| Tool | When to use | Latency | Example queries |
|------|-------------|---------|-----------------|
| `deep_search` | Default. Combines keyword + semantic + LLM reranking. | ~10s | "how does the router handle middleware" |
| `search` | Exact terms, identifiers, error strings. | ~30ms | "handleAuth", "ECONNREFUSED", "fn parse_token" |
| `vector_search` | Concepts, architectural questions, "how does X work". Also uses query expansion (vec/hyde). | ~2s | "authentication flow", "state management pattern" |

**Start with `deep_search` unless you have a specific reason not to.**

## How `deep_search` Works

Hybrid pipeline with GRPO-optimized query expansion → BM25 + vector search → RRF fusion → LLM cross-encoder reranking → position-aware blending → dedup. For pipeline internals (sub-query types, blending weights, conditional expansion logic), see [references/pipeline.md](references/pipeline.md).

Documents are chunked into 900-token pieces with 15% overlap. Search matches point to the chunk, not the exact line. Use `get` with `fromLine`/`maxLines` to narrow down.

## Tools

| Tool | Purpose |
|------|---------|
| `search` | BM25 keyword search |
| `vector_search` | Vector/semantic search |
| `deep_search` | Hybrid (BM25 + vector + expansion + reranking) |
| `get` | Retrieve one document by path |
| `multi_get` | Retrieve multiple documents |
| `status` | List collections, document counts, pending embeds |

## Context hygiene

Search results consume your main conversation context. For broad research across multiple collections, delegate to a subagent:

```
Use a subagent to research how Next.js handles routing
by searching the next.js QMD collection.
```

The subagent runs searches in its own context and returns a summary. Your main conversation stays clean.

For targeted lookups (one query, one collection), search directly — the overhead is low.

## Retrieval

After search returns results, retrieve full documents:

| Task | MCP Tool | Example |
|------|----------|---------|
| Get by path | `get` | `file: "collection/path/to/doc.md"` |
| Get by docid | `get` | `file: "#abc123"` |
| Get with line numbers | `get` | `file: "docs/api.md", lineNumbers: true` |
| Get from line offset | `get` | `file: "docs/api.md", fromLine: 100, maxLines: 50` |
| Multiple by glob | `multi_get` | `pattern: "docs/*.md"` |
| Multiple by list | `multi_get` | `pattern: "#abc123, #def456"` |

## MCP ↔ CLI Reference

| MCP Tool | CLI Equivalent | Key Parameters |
|----------|---------------|----------------|
| `search` | `qmd search` | `query`, `limit` (default 10), `minScore` (default 0), `collection` |
| `vector_search` | `qmd vsearch` (alias: `vector-search`) | `query`, `limit` (default 10), `minScore` (default 0.3), `collection` |
| `deep_search` | `qmd query` (alias: `deep-search`) | `query`, `limit` (default 10), `minScore` (default 0), `collection` |

CLI defaults: 5 results in terminal mode, 20 for `--json`/`--files`. MCP defaults: 10.

CLI supports multiple collection filters: `qmd search "query" -c react -c next.js`. MCP `collection` parameter takes a single collection name.
| `get` | `qmd get` | `file` (path or `#docid`), `fromLine`, `maxLines`, `lineNumbers` |
| `multi_get` | `qmd multi-get` | `pattern` (glob or comma list), `maxLines`, `maxBytes` (default 10KB), `lineNumbers` |
| `status` | `qmd status` | — |

CLI output formats (not available via MCP): `--files`, `--json`, `--csv`, `--md`, `--xml`. MCP returns structured content via `structuredContent` field in addition to text.

## Score Interpretation

| Score | Meaning | Action |
|-------|---------|--------|
| 0.8 - 1.0 | Highly relevant | Show to user |
| 0.5 - 0.8 | Moderately relevant | Include if few results |
| 0.2 - 0.5 | Somewhat relevant | Only if user wants more |
| 0.0 - 0.2 | Low relevance | Usually skip |

## Recommended Workflow

1. **Check what's available**: `status`
2. **Start with deep search**: `deep_search "topic"` (limit 10)
3. **Narrow with keywords if needed**: `search "exact term"`
4. **Try semantic if keywords miss**: `vector_search "describe the concept"`
5. **Retrieve full documents**: `get` with path or `#docid`

<examples>
<example name="finding_implementation_patterns">
<scenario>User asks how Next.js handles authentication middleware</scenario>
<search>
1. deep_search("authentication middleware", collection: "next.js", limit: 10)
2. Review results — pick top 3 by score
3. get(file: "next.js/packages/next/src/server/web/adapter.ts", lineNumbers: true)
4. Summarize the pattern for the user
</search>
</example>

<example name="comparing_across_repos">
<scenario>User wants to compare error handling across React and Next.js</scenario>
<search>
1. deep_search("error boundary implementation", collection: "react", limit: 5)
2. deep_search("error handling middleware", collection: "next.js", limit: 5)
3. get for top results from each
4. Compare approaches side-by-side
</search>
</example>

<example name="broad_research_with_subagent">
<scenario>User asks to research all routing patterns in Next.js</scenario>
<search>
Delegate to subagent (broad research consumes context):
"Search the next.js QMD collection for routing patterns.
 Use deep_search for 'routing', 'middleware', 'route handler', 'page router', 'app router'.
 Retrieve top results with get. Summarize findings."
</search>
</example>
</examples>

## Tips

- Run `status` first to see available collections and confirm zero pending embeddings.
- Scope searches to a collection with the `collection` parameter when you know which repo to search.
- After search returns a path, use `@<absolute-path>` to pull the full file into context (the collection path is in `qmd status`).
- If MCP tools are missing, the server may have disconnected — run `/qmd:status` as a Bash fallback.
- Multi-get with glob: `multi_get` pattern `"docs/*.md"` or comma list `"#abc, #def"`
- Get with line offset: `get` file `"docs/api.md:100"` or use fromLine + maxLines params
- Context is hierarchical: all matching path prefixes are concatenated (global → root → specific), not just the deepest match
- `vector_search` also uses query expansion internally (vec/hyde only, no lex) — it's not just BM25
- For broad research, delegate to subagent to keep main context clean

## CLI Fallback

When MCP tools are unavailable (server disconnected, not installed), use CLI:

```bash
qmd search "exact term" -c collection -n 10 --json     # BM25
qmd vsearch "concept" -c collection -n 10 --json       # Vector
qmd query "question" -c collection -n 10 --json         # Hybrid
qmd get path/to/file.md --line-numbers                  # Retrieve
qmd multi-get "docs/*.md" --json                         # Batch retrieve
```

CLI supports multiple `-c` flags: `qmd search "query" -c react -c next.js`

MCP `collection` parameter takes a single name.

## Named Indexes

QMD supports separate indexes via `--index <name>`. Config at `~/.config/qmd/<name>.yml`, DB at `~/.cache/qmd/<name>.sqlite`. Useful for work/personal separation:

```bash
qmd --index work search "deployment"
qmd --index personal search "journal"
```

## Recovery

| Problem | Cause | Fix |
|---------|-------|-----|
| MCP tools missing from tool list | Server disconnected mid-session | Run `/qmd:status` (Bash fallback) or `/mcp` to check connection |
| Zero results after successful embed | Mask excluded key files | Re-add with `/qmd:add <repo> --mask "<broader-glob>"` |
| Search hangs or times out | Index corruption or model loading | Run `qmd cleanup` then `qmd embed -f` to rebuild |
| Low-quality results | Wrong modality for query type | Switch: exact terms → `search`, concepts → `vector_search` |
| "Collection not found" error | Typo or collection was removed | Run `status` to list available collections |

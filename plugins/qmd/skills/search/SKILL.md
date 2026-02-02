---
name: search
description: When to use qmd_search, qmd_vsearch, or qmd_query across indexed reference collections.
user-invocable: false
---

# QMD Search Guide

## When to use QMD

QMD searches **reference repos** in `~/Developer/refs/` — external codebases you've indexed for learning or comparison. For files in the current working directory, use Grep and Glob instead. They're faster, cheaper on context, and more precise.

## Modality

| Tool | When to use | Example queries |
|------|-------------|-----------------|
| `qmd_query` | Default. Combines keyword + semantic + LLM reranking. | "how does the router handle middleware" |
| `qmd_search` | Exact terms, identifiers, error strings. | "handleAuth", "ECONNREFUSED", "fn parse_token" |
| `qmd_vsearch` | Concepts, architectural questions, "how does X work". | "authentication flow", "state management pattern" |

**Start with `qmd_query` unless you have a specific reason not to.**

## How `qmd_query` Works

The hybrid pipeline uses a fine-tuned query expansion model to generate 3 types of sub-queries:

| Type | Purpose | Example for "auth middleware" |
|------|---------|-------------------------------|
| `lex` | Keyword variants for BM25 | "authentication middleware handler" |
| `vec` | Semantic rephrasing for vector search | "how request authentication is validated" |
| `hyde` | Hypothetical document (imagines what the answer looks like) | "The middleware checks the JWT token and attaches the user to the request context" |

Each sub-query runs against both BM25 and vector indexes. Results are fused with Reciprocal Rank Fusion (RRF), then reranked by an LLM cross-encoder.

### Position-aware blending

After RRF fusion, the reranker scores are blended with retrieval scores using position-aware weights:

| RRF Rank | Retrieval Weight | Reranker Weight | Why |
|----------|-----------------|-----------------|-----|
| 1-3 | 75% | 25% | Protects exact keyword matches from reranker downranking |
| 4-10 | 60% | 40% | Balanced |
| 11+ | 40% | 60% | Trust reranker more for lower-ranked candidates |

This means a document that ranks #1 for your exact keywords stays near the top even if the reranker prefers a semantically similar but different document.

## Embedding Granularity

Documents are chunked into 800-token pieces with 15% overlap before embedding. Search matches point to the chunk, not the exact line. Use `qmd_get` with `fromLine`/`maxLines` to narrow down after finding the right document.

## Tools

| Tool | Purpose |
|------|---------|
| `qmd_search` | BM25 keyword search |
| `qmd_vsearch` | Vector/semantic search |
| `qmd_query` | Hybrid (BM25 + vector) |
| `qmd_get` | Retrieve one document by path |
| `qmd_multi_get` | Retrieve multiple documents |
| `qmd_status` | List collections, document counts, pending embeds |

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
| Get by path | `qmd_get` | `file: "collection/path/to/doc.md"` |
| Get by docid | `qmd_get` | `file: "#abc123"` |
| Get with line numbers | `qmd_get` | `file: "docs/api.md", lineNumbers: true` |
| Get from line offset | `qmd_get` | `file: "docs/api.md", fromLine: 100, maxLines: 50` |
| Multiple by glob | `qmd_multi_get` | `pattern: "docs/*.md"` |
| Multiple by list | `qmd_multi_get` | `pattern: "#abc123, #def456"` |

## MCP ↔ CLI Reference

| MCP Tool | CLI Equivalent | Key Parameters |
|----------|---------------|----------------|
| `qmd_search` | `qmd search` | `query`, `limit` (default 10), `minScore` (default 0), `collection` |
| `qmd_vsearch` | `qmd vsearch` | `query`, `limit` (default 10), `minScore` (default 0.3), `collection` |
| `qmd_query` | `qmd query` | `query`, `limit` (default 10), `minScore` (default 0), `collection` |
| `qmd_get` | `qmd get` | `file` (path or `#docid`), `fromLine`, `maxLines`, `lineNumbers` |
| `qmd_multi_get` | `qmd multi-get` | `pattern` (glob or comma list), `maxLines`, `maxBytes` (default 10KB), `lineNumbers` |
| `qmd_status` | `qmd status` | — |

CLI-only options (not available via MCP): `--full`, `--json`, `--csv`, `--md`, `--xml`, `--files`, `--all`.

## Score Interpretation

| Score | Meaning | Action |
|-------|---------|--------|
| 0.8 - 1.0 | Highly relevant | Show to user |
| 0.5 - 0.8 | Moderately relevant | Include if few results |
| 0.2 - 0.5 | Somewhat relevant | Only if user wants more |
| 0.0 - 0.2 | Low relevance | Usually skip |

## Recommended Workflow

1. **Check what's available**: `qmd_status`
2. **Start with hybrid search**: `qmd_query "topic"` (limit 10)
3. **Narrow with keywords if needed**: `qmd_search "exact term"`
4. **Try semantic if keywords miss**: `qmd_vsearch "describe the concept"`
5. **Retrieve full documents**: `qmd_get` with path or `#docid`

## Examples

### Finding implementation patterns
```sh
# Hybrid search for best results
qmd query "authentication implementation" --min-score 0.3 --json

# Get all relevant files for deeper analysis
qmd query "auth flow" --all --files --min-score 0.4
```

### Searching a specific collection
```sh
qmd search "middleware" -c next.js -n 5
qmd vsearch "routing architecture" -c next.js
qmd get "#abc123" --full
```

## Tips

- Run `qmd_status` first to see available collections and confirm zero pending embeddings.
- Scope searches to a collection with the collection parameter when you know which repo to search.
- After search returns a path, use `@~/Developer/refs/<name>/<path>` to pull the full file into context.
- If MCP tools are missing, the server may have disconnected — run `/qmd:status` as a Bash fallback.

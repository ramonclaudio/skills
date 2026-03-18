---
name: search
description: When to use the query MCP tool and query documents to search indexed reference collections.
user-invocable: false
---

# QMD Search Guide

## Current State
- **Collections:** !`qmd status 2>/dev/null | grep -c '^  ' || echo "0"`
- **Status:** !`qmd status 2>/dev/null | head -1 || echo "QMD not running"`

## When to use QMD

QMD searches **indexed collections**: external codebases, notes, docs you've added with `qmd collection add`. For files in the current working directory, use Grep and Glob instead. They're faster, cheaper on context, and more precise.

## Modality

| Approach | When to use | How |
|----------|-------------|-----|
| Typed queries (MCP + CLI) | You know what you need. Exact terms, semantic concepts, or both. | MCP: `searches: [{type: "lex", query: "handleAuth"}, {type: "vec", query: "how auth works"}]`. CLI: `qmd query $'lex: handleAuth\nvec: how auth works'` |
| Auto-expand (CLI only) | Most CLI queries. Let the pipeline decide. | CLI: `qmd query "auth middleware"`. Not available via MCP. |

**Use `query` for everything.** MCP accepts typed sub-queries (`lex`, `vec`, `hyde`). CLI also supports `expand:` and plain text (auto-expand).

## How `query` Works

Hybrid pipeline with GRPO-optimized query expansion → BM25 + vector search → RRF fusion → LLM cross-encoder reranking → position-aware blending → dedup. For pipeline internals (sub-query types, blending weights, conditional expansion logic), see [references/pipeline.md](references/pipeline.md).

Documents are chunked into 900-token pieces with 15% overlap. Search matches point to the chunk, not the exact line. Use `get` with `fromLine`/`maxLines` to narrow down.

## Query Document Format

The `query` tool accepts an array of typed sub-queries. **MCP** uses structured JSON: `searches: [{type: "lex", query: "term"}, ...]` with types `lex`, `vec`, `hyde` only. **CLI** uses a text format: each line has an optional type prefix (`lex: term`). CLI also supports `expand:` and plain text (auto-expand).

### Grammar

MCP `type` enum: `"lex" | "vec" | "hyde"`. CLI adds `"expand"` and implicit expand (plain text).

```
root    ::= line ("\n" line)*
line    ::= (type ":" SP)? content
type    ::= "lex" | "vec" | "hyde" | "expand"   # expand is CLI-only
content ::= [^\n]+
```

### Types

| Type | Routed to | Purpose | Availability |
|------|-----------|---------|-------------|
| `lex:` | BM25 only | Exact keywords, identifiers, error strings | MCP + CLI |
| `vec:` | Vector only | Semantic rephrasing, concept search | MCP + CLI |
| `hyde:` | Vector only | Hypothetical document. Describe what the answer looks like | MCP + CLI |
| `expand:` | Full pipeline | Auto-expand into lex/vec/hyde sub-queries. Max one per query document. | CLI only |
| _(plain text)_ | Full pipeline | Implicit `expand:`. Same as `expand:` but shorter to write. | CLI only |

### Fusion Weight

The **first query line gets 2x fusion weight** in RRF. Put your strongest signal first.

### Examples

Single line, auto-expands (CLI only):
```
auth middleware
```

Multi-line typed query:
```
lex:handleAuth JWT token
vec:how does request authentication work
hyde:The middleware validates the JWT token from the Authorization header and attaches the decoded user object to the request context
```

Mixed, typed + auto-expand (CLI only, `expand:` not available via MCP):
```
lex:"ECONNREFUSED" retry logic
expand:how connection errors are retried
```

## Lex Syntax

Lex queries support phrase matching and exclusions:

| Syntax | Meaning | Example |
|--------|---------|---------|
| `"exact phrase"` | Verbatim match | `lex:"error boundary"` |
| `-term` | Exclude term | `lex:middleware -express` |
| `-"phrase"` | Exclude phrase | `lex:router -"page router"` |
| bare words | OR match (stemmed) | `lex:handleAuth parse token` |

## Tools

| Tool | Purpose |
|------|---------|
| `query` | Search: typed sub-queries (`lex`, `vec`, `hyde`). CLI also supports `expand:` and plain text. |
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

For targeted lookups (one query, one collection), search directly. The overhead is low.

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
| `query` | `qmd query` (alias: `deep-search`) | `searches` (array of `{type, query}` objects, types: `lex`/`vec`/`hyde`, min 1, max 10), `limit` (default 10), `minScore` (default 0), `collections` (array) |
| `get` | `qmd get` | `file` (path or `#docid`), `fromLine`, `maxLines`, `lineNumbers` |
| `multi_get` | `qmd multi-get` | `pattern` (glob or comma list), `maxLines`, `maxBytes` (default 10KB), `lineNumbers` |
| `status` | `qmd status` | (none) |

CLI has additional search commands (`qmd search`, `qmd vsearch`) that map to BM25-only and vector-only searches. Use these in CLI fallback scenarios when you need a specific modality.

CLI defaults: 5 results in terminal mode, 20 for `--json`/`--files`. MCP defaults: 10.

CLI supports multiple collection filters: `qmd search "query" -c react -c next.js`. MCP `collections` parameter takes an array of collection names.

CLI output formats (not available via MCP): `--files`, `--json`, `--csv`, `--md`, `--xml`. MCP returns structured content via `structuredContent` field in addition to text.

## Score Interpretation

| Score | Meaning | Action |
|-------|---------|--------|
| 0.8 - 1.0 | Highly relevant | Show to user |
| 0.5 - 0.8 | Moderately relevant | Include if few results |
| 0.2 - 0.5 | Somewhat relevant | Only if user wants more |
| 0.0 - 0.2 | Low relevance | Usually skip |

## Recommended Workflow

1. Check what's available: `status`
2. Search: `query` with `lex`/`vec`/`hyde` sub-queries
3. Refine: `lex:"exact term"` for identifiers, `vec:` for concepts, combine in one query document
4. Retrieve full documents: `get` with path or `#docid`

<examples>
<example name="finding_implementation_patterns">
<scenario>User asks how Next.js handles authentication middleware</scenario>
<search>
1. query(searches: [{type: "lex", query: "authentication middleware"}, {type: "vec", query: "how auth middleware validates requests"}], collections: ["next.js"], limit: 10)
2. Review results, pick top 3 by score
3. get(file: "next.js/packages/next/src/server/web/adapter.ts", lineNumbers: true)
4. Summarize the pattern for the user
</search>
</example>

<example name="typed_query_for_precision">
<scenario>User asks about a specific error in a known function</scenario>
<search>
1. query with typed query document:
   lex:"NEXT_NOT_FOUND" handleNotFound
   vec:how the not-found error propagates through the router
   collections: ["next.js"], limit: 10
2. get for top result with lineNumbers
</search>
</example>

<example name="comparing_across_repos">
<scenario>User wants to compare error handling across React and Next.js</scenario>
<search>
1. query(searches: [{type: "lex", query: "error boundary"}, {type: "vec", query: "error boundary implementation"}], collections: ["react"], limit: 5)
2. query(searches: [{type: "lex", query: "error handling middleware"}, {type: "vec", query: "how errors are handled in middleware"}], collections: ["next.js"], limit: 5)
3. get for top results from each
4. Compare approaches side-by-side
</search>
</example>

<example name="broad_research_with_subagent">
<scenario>User asks to research all routing patterns in Next.js</scenario>
<search>
Delegate to subagent (broad research consumes context):
"Search the next.js QMD collection for routing patterns.
 Use query for 'routing', 'middleware', 'route handler', 'page router', 'app router'.
 Retrieve top results with get. Summarize findings."
</search>
</example>
</examples>

## Tips

- Run `status` first to see available collections and confirm zero pending embeddings.
- Scope searches with the `collections` array parameter when you know which repos to search.
- First query line gets 2x fusion weight. Put your strongest signal first.
- Use typed queries when auto-expand misses: `lex:` for exact identifiers, `vec:` for concepts, `hyde:` for "what would the answer look like".
- Max one `expand:` per query document (CLI only). Multiple `lex:`/`vec:`/`hyde:` lines are fine.
- After search returns a path, use `@<absolute-path>` to pull the full file into context (the collection path is in `qmd status`).
- If MCP tools are missing, the server may have disconnected. Run `/qmd:status` as a Bash fallback.
- Multi-get with glob: `multi_get` pattern `"docs/*.md"` or comma list `"#abc, #def"`
- Get with line offset: `get` file `"docs/api.md:100"` or use fromLine + maxLines params
- Context is hierarchical: all matching path prefixes are concatenated (global → root → specific), not just the deepest match
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

All 3 CLI search commands remain available. MCP has only `query`.

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
| Low-quality results | Query too vague or wrong approach | Use typed queries: `lex:` for exact terms, `vec:` for concepts, combine both |
| "Collection not found" error | Typo or collection was removed | Run `status` to list available collections |

## Gotchas

- `minScore: 0.5` filters too aggressively for broad queries. Use 0.3 for exploratory search.
- BM25 (`lex`) is better for exact identifiers. Vec is better for concepts. Combine both for best recall.
- `expand:` and plain text auto-expand are CLI-only. MCP requires explicit typed queries.
- Chunks are 900 tokens with 15% overlap. Search matches point to chunks, not exact lines. Use `get` with `fromLine`/`maxLines` to narrow down.

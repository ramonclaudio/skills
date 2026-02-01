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
| `qmd_query` | Default. Combines keyword + semantic. | "how does the router handle middleware" |
| `qmd_search` | Exact terms, identifiers, error strings. | "handleAuth", "ECONNREFUSED", "fn parse_token" |
| `qmd_vsearch` | Concepts, architectural questions, "how does X work". | "authentication flow", "state management pattern" |

**Start with `qmd_query` unless you have a specific reason not to.**

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

## Tips

- Run `qmd_status` first to see available collections and confirm zero pending embeddings.
- Scope searches to a collection with the collection parameter when you know which repo to search.
- After search returns a path, use `@~/Developer/refs/<name>/<path>` to pull the full file into context.
- If MCP tools are missing, the server may have disconnected — run `/qmd:status` as a Bash fallback.

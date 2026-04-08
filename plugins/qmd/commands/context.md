---
description: Manage qmd collection contexts (list, add, rm). Contexts are descriptive metadata returned alongside every search hit.
allowed-tools: Bash(qmd context*)
argument-hint: <list|add|rm> [path] [text]
---

Route based on the first token in `$ARGUMENTS`:

- **`list`** — `qmd context list`. Show all configured contexts grouped by collection.
- **`add [path] "<text>"`** — `qmd context add $ARGUMENTS`.
  - One-arg form (`add "text"`) uses cwd and auto-detects the collection.
  - Two-arg form takes an explicit path. Path formats:
    - `qmd://collection/path` — virtual path inside a collection (recommended)
    - `/` — global context, applies to every collection
    - `.` or relative path — auto-resolved from cwd
    - Absolute filesystem path — collection detected by longest-prefix match
  - Collection names must match `[a-zA-Z0-9_-]+`.
- **`rm <path>`** (alias `remove`) — `qmd context rm $ARGUMENTS`. Accepts both filesystem paths and `qmd://` URIs.

Context is hierarchical: when a search hits a path, qmd concatenates ALL matching prefixes (global → root → specific subdir), joined with `\n\n`. Adding context at multiple levels is additive, not overriding.

**What context actually does:** the qmd MCP server returns the document's full hierarchical context block in every search result's `context` field. Claude (and other LLM callers) sees the context alongside the snippet so it knows what kind of document it's reading. Context is **purely descriptive metadata**. It does NOT influence chunk selection, reranking, or scoring — those are driven by the query terms and the optional `intent` parameter, not by the YAML `context:` field.

So context's job is to TELL the model "this snippet comes from a Convex schema example, not a tutorial blog post." A short, specific context (one sentence) is better than a long one because the full string gets prepended to every result's snippet.

The `/qmd:add` SKILL writes the initial root context once at clone/register time. Use this command to update the root context or add deeper paths later (e.g. `qmd://next.js/docs/api` → "Stable App Router API reference").

If `$ARGUMENTS` is empty or the subcommand is unrecognized, print: `usage: /qmd:context <list|add|rm> [args]`.

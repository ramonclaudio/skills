---
name: search
description: Search indexed reference codebases (Convex, Expo, Next.js, Better Auth, Remotion, etc) via the qmd MCP query tool. Use when looking up framework APIs, finding code examples in third-party repos, or answering questions about external libraries that aren't in the current working directory.
user-invocable: false
allowed-tools:
  - mcp__qmd__query
  - mcp__qmd__get
  - mcp__qmd__multi_get
  - mcp__qmd__status
---

# QMD Search

Decision rules and patterns for searching indexed reference collections via the qmd MCP server.

## Status

- **Index:** !`qmd status 2>/dev/null | head -1 || echo "qmd not running"`
- **Collections:** !`qmd status 2>/dev/null | grep -cE '^  [a-z]' || echo 0`

## When to use QMD vs Grep/Glob

| Source of files | Use |
|-----------------|-----|
| The current working directory (the user's repo) | `Grep`, `Glob`, `Read` |
| Indexed reference repos (`~/Developer/refs/*`) | `mcp__qmd__query` |
| Personal notes / docs that the user added with `/qmd:add` | `mcp__qmd__query` |

QMD is for content you can't reach with `Grep` because it's outside the working tree. Don't use it for files in the current project — `Grep`/`Glob` are faster, cheaper, and more precise.

## Pipeline note (matters for query quality)

The MCP `query` tool calls `structuredSearch`, which **skips the local LLM query expansion**. The model never gets a chance to fix a vague `vec:` line. You (Claude) are the expansion model. Compose typed sub-queries deliberately:

- `lex:` for exact terms, identifiers, error codes, file/symbol names
- `vec:` for semantic phrasing of the user's question
- `hyde:` for nuanced topics — write 50-100 words of what the answer would look like
- `intent:` for any ambiguous keyword (treat as required, see below)

The first sub-query gets 2x weight in RRF fusion. Put your strongest signal first.

The upstream MCP server already injects a full description of the `query` tool with grammar, lex syntax, and worked examples — you don't need to memorize it, but you should compose queries with the same care you'd put into a vector DB query.

## Intent: treat as required

The MCP server's standing instruction is:

> Always provide `intent` on every search call to disambiguate and improve snippets.

Follow it. `intent` doesn't search on its own — it steers query expansion, reranking, chunk selection, and snippet extraction. A 5-word intent string is essentially free and dramatically improves results for any keyword that's overloaded across domains.

Words that almost always need intent: `performance`, `state`, `cache`, `pool`, `worker`, `signal`, `frame`, `model`, `router`, `context`, `session`, `migration`, `lock`, `queue`, `channel`, `agent`, `bridge`, `binding`, `hook`, `provider`, `adapter`, `client`, `store`.

Good intent is specific to the user's actual stack:

- `"Convex authQuery wrapper for row-level security"` (not `"auth"`)
- `"Expo SDK 56 native module bridging on iOS"` (not `"native module"`)
- `"Next.js App Router server action with form action prop"` (not `"server action"`)
- `"Postgres advisory lock for cron leader election"` (not `"locking"`)

## Collections filter

Always pass `collections: [...]` when you know which repo(s) to search. The indexed set changes over time, so run `mcp__qmd__status` once per session to see the live list rather than assuming a fixed roster. Names follow a stable convention: `<framework>-docs` for markdown docs, `<framework>-src` for TypeScript source, `<tool>-skills` for agent skill guides, plus `qmd` itself.

Omitting `collections` searches every default collection, which is slower and dilutes signal.

Collections marked `includeByDefault: false` are silently skipped unless explicitly named in the `collections` array. The MCP `status` tool's response does NOT include the include/exclude state, so you can't tell from `mcp__qmd__status` which collections are excluded — if a search returns nothing and the user expected results from a known collection, check via the bash fallback `qmd collection list` (which marks excluded ones with `[excluded]`) or `qmd collection show <name>`.

## Named indexes

qmd supports separate indexes via `--index <name>`. Each named index has its own SQLite DB and YAML config:

- Default: `${XDG_CACHE_HOME:-~/.cache}/qmd/index.sqlite` + `${XDG_CONFIG_HOME:-~/.config}/qmd/index.yml`
- Named: `${XDG_CACHE_HOME:-~/.cache}/qmd/<name>.sqlite` + `${XDG_CONFIG_HOME:-~/.config}/qmd/<name>.yml`

The plugin's MCP server uses the default index. If the user has set up additional indexes (e.g. `work` for client repos, `personal` for notes), search them via the CLI fallback:

```bash
qmd --index work query "deployment runbook"
qmd --index personal query "journal entry about last summer"
```

Ask the user which index they want before searching if it's ambiguous. Most setups use only the default.

## Score interpretation

| Score | Meaning | Action |
|-------|---------|--------|
| 0.8 – 1.0 | Highly relevant | Show to user |
| 0.5 – 0.8 | Moderately relevant | Include if few results, otherwise filter |
| 0.2 – 0.5 | Somewhat relevant | Only if user wants more |
| 0.0 – 0.2 | Low relevance | Usually skip |

`minScore` calibration:

- **Default `minScore: 0`** is right for exploratory queries — don't pre-filter.
- **`minScore: 0.3`** is the right floor when you want to prune obvious junk but keep partial matches.
- **`minScore: 0.5`** is too aggressive for broad queries and will return zero rows for anything semantic. Only use for narrow, high-confidence lookups (exact identifier with `lex:` only).

If a search returns zero results with `minScore: 0.5`, retry without it before assuming the content isn't there.

## Subagent hygiene

Search results take real space in your context. For broad research (multiple queries, many results), delegate to a subagent so the raw retrieval stays out of the main thread:

```
Use the Explore subagent to research how Convex handles row-level security across the convex-docs and convex-src collections. Use mcp__qmd__query and mcp__qmd__get. Return a summary with file:line references.
```

For targeted lookups (one query, one collection, top 5 results), search directly. The overhead is fine.

## Retrieval

`get` returns an MCP `resource` content block with a `qmd://` URI and `text/markdown` mime type. Claude Code surfaces it as a document attachment, not inline text. Same for `multi_get` (one resource per file, plus text blocks for errors/skips).

Search results now carry an absolute source-file `line` (qmd 2.5.0), so you can pass a hit's `line` straight to `get` as `fromLine` to land near the match. The snippet still covers the best matching chunk (~900 tokens), so widen with `maxLines` when you need surrounding context.

**`@<absolute-path>` shortcut:** when a search hit points to a file on disk, you can reference it inline via `@/Users/.../refs/next.js/packages/.../router.ts` to attach the whole file to your reply context without calling `get`. The collection's on-disk path is in `mcp__qmd__status`. Useful when the user wants to see the full file rather than a chunked snippet.

## Recovery

| Symptom | Cause | Fix |
|---------|-------|-----|
| Search returns nothing, errors, or misbehaves after an upgrade | Model, GPU, or index health | Run `/qmd:doctor` first to isolate it |
| `mcp__qmd__*` tools missing from your tool list | MCP server disconnected | Run `/qmd:status` (Bash fallback) or `/mcp` to check |
| Zero results after a successful index | Mask excluded the relevant files | Re-add with `/qmd:add <repo> --mask "<broader-glob>"` |
| Timeouts or hangs | Index corruption | `/qmd:doctor`, then `/qmd:cleanup` and `/qmd:embed -f` |
| Low-quality results | Vague vec query, no intent | Tighten `lex:`, add `intent:`, add a `hyde:` line |
| "Collection not found" | Typo or removed collection | `mcp__qmd__status` to list current collections |

## CLI fallback

When the MCP server is down, fall back to bash via the slash commands or directly:

```bash
qmd query "<question>" -c <collection>             # Hybrid (slowest, highest quality)
qmd query "<question>" --no-rerank -C 20           # Fast path: skip reranker, fewer candidates
qmd search "<exact term>" -c <collection>          # BM25 only (fastest, no LLM)
qmd get <path> --line-numbers                      # Retrieve a single doc
qmd multi-get "docs/*.md" --json --max-bytes 20480 # Batch retrieve with size cap
qmd query "<q>" --intent "<domain>" --explain --json  # Debug score traces
qmd ls <collection>                                # Browse files in a collection (ls -l style)
qmd ls <collection>/<path>                         # Browse a subdirectory
qmd ls qmd://<collection>/<path>                   # Same, via virtual URI
qmd collection list                                # Show all collections + ignore globs + [excluded] tags
```

CLI accepts multiple `-c` flags for cross-collection search. `qmd ls` is the only way to discover files in a collection without searching — useful when verifying that an `/qmd:add` mask actually indexed the right files, or when the user asks "what's in this collection?"

## Examples

For worked examples covering common patterns (precision queries, hyde for nuance, intent-aware disambiguation, subagent delegation), see [references/examples.md](references/examples.md).

For pipeline internals (chunking, RRF blending, position-aware reranking, AST chunking), see [references/pipeline.md](references/pipeline.md).

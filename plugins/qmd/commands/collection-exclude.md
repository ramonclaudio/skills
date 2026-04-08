---
description: Exclude a qmd collection from default queries (sets includeByDefault false). Use for noisy or session-scoped collections.
allowed-tools: Bash(qmd collection exclude*)
argument-hint: <name>
---

Run `qmd collection exclude $ARGUMENTS`. Sets `includeByDefault: false` for the collection in YAML.

Excluded collections are skipped in searches that don't pass an explicit `collections: [...]` filter. They stay fully indexed and embedded — they just don't dilute default queries.

When to use:

- A noisy notes folder you only want to search intentionally (`sessions/`, `scratch/`, `inbox/`)
- A huge corpus that drowns out other collections (`linux-kernel`, monorepo dumps)
- An old reference repo you keep around but rarely query

To search an excluded collection on demand:

- MCP: `mcp__qmd__query(searches: [...], collections: ["<excluded-name>"])`
- CLI: `qmd query "..." -c <excluded-name>`

To verify: `/qmd:collection-show <name>` prints `Include: no`. Only `qmd collection list` (CLI direct) marks excluded collections with a `[yellow][excluded]` tag in its summary output. `qmd status` and the MCP `status` tool do NOT show include state. Reverses `/qmd:collection-include`.

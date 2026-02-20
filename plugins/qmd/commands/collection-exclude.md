---
description: Exclude a collection from default queries
allowed-tools:
  - Bash(qmd collection exclude*)
argument-hint: <name>
---

Run `qmd collection exclude $ARGUMENTS`.

Sets `includeByDefault: false` for the collection. The collection is hidden from all queries unless explicitly named via the `collections` parameter.

Use this for large or noisy collections you only want to search intentionally.

To search an excluded collection: `qmd query "term" -c excluded-collection` (CLI) or `collections: ["excluded-collection"]` (MCP).

Opposite of `qmd collection include`. `qmd collection list` shows `[excluded]` tag for excluded collections.

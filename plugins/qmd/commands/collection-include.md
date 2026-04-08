---
description: Include a qmd collection in default queries (sets includeByDefault true). Reverses /qmd:collection-exclude.
allowed-tools: Bash(qmd collection include*)
argument-hint: <name>
---

Run `qmd collection include $ARGUMENTS`. Sets `includeByDefault: true` for the collection in YAML.

`true` is the default state. Including a collection means it shows up in every search where the user (or Claude) doesn't pass an explicit `collections: [...]` filter. Reverses `/qmd:collection-exclude`.

To verify the change, suggest `/qmd:collection-show <name>` (which prints `Include: yes (default)` or `no`). Note that `/qmd:status` and the MCP `status` tool do NOT show include/exclude state — only `qmd collection list` (CLI direct) and `qmd collection show` do.

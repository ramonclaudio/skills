---
description: Manage QMD collection contexts (list, add, remove, check)
allowed-tools: Bash(qmd context*)
argument-hint: <subcommand> [args]
---

Route based on the first argument:

- `list` — Run `qmd context list`. Show all configured contexts grouped by collection.
- `add [path] "<text>"` — Run `qmd context add $ARGUMENTS`. One-arg form (`qmd context add "text"`) uses cwd, auto-detecting the collection from current directory. Two-arg form specifies path explicitly. Path formats:
  - `/` for global context (applies to all collections)
  - `qmd://collection/path` virtual paths (e.g., `qmd://next.js/packages`)
  - `.` or relative paths (auto-resolved from cwd)
  - Absolute filesystem paths
  Path resolution: virtual paths parsed for collection + validated, filesystem paths use longest prefix match to detect collection, relative paths resolved from cwd. Valid collection names match `[a-zA-Z0-9_-]+` regex.
- `rm <path>` (alias: `remove`) — Run `qmd context rm $ARGUMENTS`. Supports both filesystem paths and `qmd://` URIs.
- `check` — Run `qmd context check`. Reports collections without ANY context and top-level directories without context. Suggests adding per-directory descriptions.

Context hierarchy: all matching path prefixes are concatenated (global_context → root → specific), joined with `\n\n`. Not just the deepest match.

If no arguments or unrecognized subcommand, print available subcommands: `list`, `add`, `rm`, `check`.

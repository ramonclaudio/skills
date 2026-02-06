---
description: Manage QMD collection contexts (list, add, remove, check)
allowed-tools: Bash(qmd context*)
argument-hint: <subcommand> [args]
---

Route based on the first argument:

- `list` — Run `qmd context list`. Show all configured contexts (global and per-collection).
- `add <path> "<text>"` — Run `qmd context add $ARGUMENTS`. Use `qmd://` virtual paths for collection-specific contexts, `/` for global context.
- `rm <path>` — Run `qmd context rm $ARGUMENTS`. Use `qmd://` virtual paths or `/` for global.
- `check` — Run `qmd context check`. Report collections and top-level paths that are missing context descriptions.

If no arguments or unrecognized subcommand, print available subcommands: `list`, `add`, `rm`, `check`.

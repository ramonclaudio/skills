---
description: Add a local directory as a QMD collection
allowed-tools:
  - Bash(qmd collection add*)
  - Bash(qmd status*)
argument-hint: <path> [--name N] [--mask P]
---

Run `qmd collection add $ARGUMENTS`.

This adds a local directory to the QMD index. For GitHub repos, use `/qmd:add` instead. It handles cloning, mask detection, context, and embedding.

Flags:
- `--name <name>`: collection name (optional, auto-generated from directory name via `handelize()` if omitted). Must match `[a-zA-Z0-9_-]+`.
- `--mask <pattern>`: glob pattern for file inclusion (default: `**/*.md`)

Behavior:
1. Resolves path (`.` = cwd, `~/` = home, relative paths resolved from cwd)
2. Adds collection to `~/.config/qmd/index.yml`
3. Indexes files matching the glob pattern
4. Reports: new, updated, unchanged counts

Exclusions (always skipped): `node_modules`, `.git`, `.cache`, `vendor`, `dist`, `build`, hidden files/folders (starting with `.`)

After adding, run `qmd embed` to generate vector embeddings for semantic search.

If collection name already exists: the command will error. Remove first with `qmd collection remove <name>`, then re-add.

Example:
```bash
qmd collection add ~/Documents/notes --name notes
qmd collection add ~/Developer/refs/react --name react --mask "**/*.{md,ts,tsx,js,jsx}"
qmd collection add .  # indexes cwd with default mask (**/*.md), name from dir
```

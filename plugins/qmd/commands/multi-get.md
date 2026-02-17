---
description: Retrieve multiple documents by glob or comma list (CLI fallback for multi_get)
allowed-tools: Bash(qmd multi-get*)
argument-hint: <pattern> [-l N] [--max-bytes N] [--json|--csv|--md|--xml|--files]
---

Run `qmd multi-get $ARGUMENTS`.

This is the CLI fallback for `multi_get` MCP tool — use when MCP is down.

Pattern formats:
- Glob: `"docs/*.md"`, `"next.js/packages/**/*.ts"`
- Comma-separated: `"#abc123, #def456, collection/path.md"`
- Docids: `"#abc, #def, #123"`

Flags:
- `-l <num>`: max lines per file
- `--max-bytes <num>`: skip files larger than N bytes (default: 10240 = 10KB)
- `--line-numbers`: add line numbers to output
- Output: `--json`, `--csv`, `--md`, `--xml`, `--files`

Files exceeding `--max-bytes` are marked as skipped with reason. Each file includes context from hierarchical path config.

Prefer MCP `multi_get` tool when available.

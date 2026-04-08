---
description: Retrieve a document body by path or docid via the qmd CLI. CLI fallback for the MCP get tool.
allowed-tools: Bash(qmd get*)
argument-hint: <file>[:line] [--from N] [-l N] [--line-numbers]
---

Run `qmd get $ARGUMENTS`. Prints a document body to stdout.

Path resolution order:

1. Docid: `#abc123` (6-char content hash)
2. Virtual path: `qmd://collection/path/to/file.md`
3. Collection-prefixed: `next.js/docs/api.md`
4. Filesystem: absolute, `~/`, or relative path
5. Suffix match (last resort)

Useful flags:
- `file.md:N` — start at line N (shorthand for `--from N`)
- `--from N` / `-l N` — line offset and max lines
- `--line-numbers` — prefix each line with `N: `

CLI prints "Document not found" on miss; the MCP `get` tool also suggests similar files via Levenshtein-style suffix matching, which the CLI does not.

Prefer the MCP `get` tool when available — it returns a `resource` content block that Claude Code surfaces as a document attachment, not just stdout text.

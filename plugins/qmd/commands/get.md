---
description: Retrieve a document by path, docid, or virtual path (CLI fallback for get)
allowed-tools: Bash(qmd get*)
argument-hint: <file>[:line] [--from N] [-l N] [--line-numbers]
---

Run `qmd get $ARGUMENTS`.

This is the CLI fallback for `get` MCP tool — use when MCP is down.

Path formats (in resolution order):
1. Docid: `#abc123` or `abc123` (6-char content hash prefix)
2. Virtual path: `qmd://collection/path/to/file.md`
3. Collection/path: `collection/path/to/file.md`
4. Filesystem: `/absolute/path` or `~/path` or relative path
5. Suffix match: if exact match fails, tries matching end of path

Line range: `file.md:100` starts at line 100 (shorthand for --from 100).

Flags:
- `--from <N>`: start from line N (1-indexed)
- `-l <N>`: maximum lines to return
- `--line-numbers`: prefix each line with line number ("N: content")

Output: optional context header (from hierarchical context config) + document body.

If not found: suggests similar files via Levenshtein distance fuzzy matching (top 5 closest paths).

Prefer MCP `get` tool when available — this command is for when MCP is down or for piping output.

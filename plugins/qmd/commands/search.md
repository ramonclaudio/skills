---
description: BM25 keyword search across indexed collections (CLI fallback for search)
allowed-tools: Bash(qmd search*)
argument-hint: <query> [-n N] [-c collection] [--json|--csv|--md|--xml|--files]
---

Run `qmd search $ARGUMENTS`.

This is the CLI fallback for `search` MCP tool — use when MCP is down.

BM25 full-text search. ~30ms, no LLM calls. Best for exact terms, identifiers, error strings.

Flags:
- `-n <num>`: max results (default: 5 for cli, 20 for --json/--files)
- `--all`: return all matches (limit=100000)
- `--min-score <num>`: minimum score 0-1 (default: 0)
- `--full`: output full document instead of snippet
- `--line-numbers`: add line numbers to output
- `-c <name>` / `--collection <name>`: filter to collection (repeatable for multi-collection)
- Output: `--json`, `--csv`, `--md`, `--xml`, `--files`

Multiple collections: `qmd search "query" -c react -c next.js`

Prefer MCP `search` tool when available — this command is for when MCP is down or for piping output.

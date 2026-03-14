---
description: BM25 keyword search (CLI only, MCP `search` tool removed in v1.0.8, use `query` with `lex:` prefix instead)
allowed-tools: Bash(qmd search*)
argument-hint: <query> [-n N] [-c collection] [--json|--csv|--md|--xml|--files]
---

Run `qmd search $ARGUMENTS`.

BM25 full-text search. ~30ms, no LLM calls. Best for exact terms, identifiers, error strings.

MCP equivalent: use the `query` tool with `lex:` prefix for BM25 keyword search.

Flags:
- `-n <num>`: max results (default: 5 for cli, 20 for --json/--files)
- `--all`: return all matches (limit=100000)
- `--min-score <num>`: minimum score 0-1 (default: 0)
- `--full`: output full document instead of snippet
- `--line-numbers`: add line numbers to output
- `-c <name>` / `--collection <name>`: filter to collection (repeatable for multi-collection)
- Output: `--json`, `--csv`, `--md`, `--xml`, `--files`

Multiple collections: `qmd search "query" -c react -c next.js`

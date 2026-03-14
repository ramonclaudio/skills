---
description: Semantic search (CLI only, MCP uses `query` tool with type "vec")
allowed-tools: Bash(qmd vsearch*)
argument-hint: <query> [-n N] [-c collection] [--json|--csv|--md|--xml|--files]
---

Run `qmd vsearch $ARGUMENTS`.

Alias: `qmd vector-search`

Semantic search with query expansion + RRF fusion. ~2s latency. No reranking step. Best for concepts, "how does X work" questions, architectural queries.

MCP equivalent: use the `query` tool with `{type: "vec", query: "..."}` for semantic search.

Uses query expansion internally (vec/hyde types only, no lex). Default min-score: 0.3.

Flags:
- `-n <num>`: max results (default: 5 for cli, 20 for --json/--files)
- `--all`: return all matches (limit=100000)
- `--min-score <num>`: minimum score 0-1 (default: 0.3)
- `--full`: output full document instead of snippet
- `--line-numbers`: add line numbers to output
- `-c <name>` / `--collection <name>`: filter to collection (repeatable)
- Output: `--json`, `--csv`, `--md`, `--xml`, `--files`

Requires embeddings. If `qmd status` shows pending embeddings, run `qmd embed` first.

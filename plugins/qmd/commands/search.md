---
description: BM25 keyword search via the qmd CLI. Fast, no LLM. CLI fallback for the MCP query tool with type "lex".
allowed-tools: Bash(qmd search*)
argument-hint: <query> [-c collection] [-n N] [--json|--md|--files]
---

Run `qmd search $ARGUMENTS`. BM25 full-text search via SQLite FTS5. ~30 ms, no LLM calls.

Best for: exact identifiers, function names, error strings, file paths, code symbols.

Useful flags:
- `-c <name>` (repeatable) — filter to one or more collections
- `-n <num>` — max results (default 5, or 20 with `--json`/`--files`)
- `--all` — return all matches (pair with `--min-score`)
- `--json` / `--md` / `--files` — output format
- `--line-numbers` — include line numbers in snippets

Lex syntax: `"phrase"` for exact match, `-term` for negation. Example: `qmd search '"connection pool" timeout -redis'`.

Prefer the MCP `query` tool with `{type: "lex", query: "..."}` when available — it returns richer results and integrates with the rest of the pipeline.

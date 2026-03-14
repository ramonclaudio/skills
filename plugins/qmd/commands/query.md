---
description: Primary search tool, hybrid pipeline with query document support
allowed-tools: Bash(qmd query*)
argument-hint: <query> [-n N] [-c collection] [--json|--csv|--md|--xml|--files]
---

Run `qmd query $ARGUMENTS`.

This is the CLI equivalent of the `query` MCP tool. Use when MCP is down.

Full hybrid pipeline: BM25 probe → conditional expansion → parallel FTS+vector → RRF fusion (k=60) → top-40 candidates → LLM reranking → position-aware blending → dedup. ~10s latency. Most accurate.

Skips expensive expansion when BM25 returns a strong signal (top score >= 0.85, gap to #2 >= 0.15).

Supports query document format with typed sub-queries via `$'lex: ...\nvec: ...'` syntax. Sub-query types: `lex:` (BM25 keyword), `vec:` (semantic embedding), `hyde:` (hypothetical document), `expand:` (auto-expansion). Lex syntax supports `"phrase"` for exact match and `-term` for negation.

Flags:
- `-n <num>`: max results (default: 5 for cli, 20 for --json/--files)
- `--all`: return all matches (limit=100000)
- `--min-score <num>`: minimum score 0-1 (default: 0)
- `--full`: output full document instead of snippet
- `--line-numbers`: add line numbers to output
- `-c <name>` / `--collection <name>`: filter to collection (repeatable)
- Output: `--json`, `--csv`, `--md`, `--xml`, `--files`

Alias: `qmd deep-search` (note: the `deep_search` MCP tool no longer exists. Use the `query` MCP tool instead)

Requires embeddings and all 3 GGUF models. First query is slower while models load into VRAM.

Prefer MCP `query` tool when available.

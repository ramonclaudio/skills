---
description: Hybrid deep search with expansion + reranking (CLI fallback for deep_search)
allowed-tools: Bash(qmd query*)
argument-hint: <query> [-n N] [-c collection] [--json|--csv|--md|--xml|--files]
---

Run `qmd query $ARGUMENTS`.

This is the CLI fallback for `deep_search` MCP tool — use when MCP is down.

Full hybrid pipeline: BM25 probe → conditional expansion → parallel FTS+vector → RRF fusion (k=60) → top-40 candidates → LLM reranking → position-aware blending → dedup. ~10s latency. Most accurate.

Skips expensive expansion when BM25 returns a strong signal (top score >= 0.85, gap to #2 >= 0.15).

Flags:
- `-n <num>`: max results (default: 5 for cli, 20 for --json/--files)
- `--all`: return all matches (limit=100000)
- `--min-score <num>`: minimum score 0-1 (default: 0)
- `--full`: output full document instead of snippet
- `--line-numbers`: add line numbers to output
- `-c <name>` / `--collection <name>`: filter to collection (repeatable)
- Output: `--json`, `--csv`, `--md`, `--xml`, `--files`

Alias: `qmd deep-search`

Requires embeddings and all 3 GGUF models. First query is slower while models load into VRAM.

Prefer MCP `deep_search` tool when available.

---
description: Hybrid BM25 + vector + reranking search via the qmd CLI. CLI fallback for the MCP query tool.
allowed-tools: Bash(qmd query*)
argument-hint: <query> [-c collection] [--intent T] [--no-rerank] [-C N] [--explain] [-n N] [--json]
---

Run `qmd query $ARGUMENTS`. Full hybrid pipeline: BM25 + vector + RRF fusion + LLM reranking + position-aware blending. ~10s for plain queries, ~3-8s for typed query documents.

Two paths:

- **Plain string** (`qmd query "auth middleware"`): runs the local 1.7B expansion model first, then the hybrid pipeline. Slower but lets the pipeline pick types for you.
- **Typed query document** (`qmd query $'lex: handleAuth\nvec: how does auth middleware verify requests'`): skips expansion entirely. Faster. Same path the MCP `query` tool takes.

Useful flags:
- `--intent <text>` — disambiguate ambiguous keywords (effectively required for vague queries; see search SKILL)
- `--no-rerank` — skip LLM reranker, return RRF-fused scores only (much faster on CPU)
- `-C <n>` / `--candidate-limit <n>` — cap candidates passed to reranker (default 40)
- `--explain` — emit per-result score traces (FTS, vector, RRF, reranker, blended)
- `--chunk-strategy auto` — AST-aware chunk selection (should match what you embedded with)
- `-c <name>` (repeatable), `-n <num>`, `--json`, `--all`, `--min-score <n>`

Lex sub-grammar: `"phrase"` for exact match, `-term` for negation, prefix match by default.

Prefer the MCP `query` tool when available — same pipeline, structured output, no shell escaping headaches. This command is the CLI fallback when the MCP server is down.

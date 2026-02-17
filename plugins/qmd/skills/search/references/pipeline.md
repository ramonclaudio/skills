# QMD Hybrid Pipeline Internals

## Query Expansion

The hybrid pipeline uses a GRPO-optimized query expansion model (fine-tuned from Qwen3-1.7B with Group Relative Policy Optimization) to generate 3 types of sub-queries:

| Type | Purpose | Routed to | Example for "auth middleware" |
|------|---------|-----------|-------------------------------|
| `lex` | Keyword variants | BM25 only | "authentication middleware handler" |
| `vec` | Semantic rephrasing | Vector only | "how request authentication is validated" |
| `hyde` | Hypothetical document | Vector only | "The middleware checks the JWT token and attaches the user to the request context" |

Each sub-query is type-routed to the appropriate backend: `lex` queries run BM25 keyword search only, `vec` and `hyde` queries run vector search only. This eliminates wasted backend calls (~10 → 6 per query).

Expansion is conditional — when the BM25 probe returns a strong signal (top score >= 0.85 AND gap to second result >= 0.15), expansion is skipped entirely to save compute.

Note: `vector_search` also uses query expansion internally, filtered to `vec` and `hyde` types only (no `lex`). It's not just `deep_search` that expands queries.

## RRF Fusion

Results from all search backends are fused with Reciprocal Rank Fusion (RRF, k=60). The first two result lists (original BM25 results + original vector results) get 2x weight; expanded query results get 1x weight.

Top-rank bonuses are applied after RRF:
- Rank 0 (top result): +0.05
- Ranks 1-2: +0.02

After fusion, the top 40 candidates (RERANK_CANDIDATE_LIMIT) pass to the reranker.

## Reranking

For each candidate document, the pipeline picks the single best chunk (by keyword overlap with the query) and sends only that chunk to the LLM cross-encoder reranker. There is no multi-chunk score aggregation — one chunk per document.

The reranker uses node-llama-cpp's `createRankingContext()` and `rankAll()` API with a 2048-token context window and flash attention enabled.

## Position-Aware Blending

After reranking, reranker scores are blended with RRF retrieval scores using position-aware weights:

| RRF Rank | Retrieval Weight | Reranker Weight | Why |
|----------|-----------------|-----------------|-----|
| 1-3 | 75% | 25% | Protects exact keyword matches from reranker downranking |
| 4-10 | 60% | 40% | Balanced |
| 11+ | 40% | 60% | Trust reranker more for lower-ranked candidates |

**Formula:** `blendedScore = rrfWeight * (1/rrfRank) + (1 - rrfWeight) * rerankerScore`

This means a document that ranks #1 for your exact keywords stays near the top even if the reranker prefers a semantically similar but different document.

## Chunking and Embedding

Documents are chunked into 900-token pieces (≈3600 chars) with 15% overlap (135 tokens). The chunker uses scored markdown breakpoints with the following priority:

| Break type | Score |
|-----------|-------|
| H1 | 100 |
| H2 | 90 |
| H3 | 80 |
| H4 / code block | 70-80 |
| H5-H6 / horizontal rule | 50-60 |
| Blank line (paragraph boundary) | 20 |
| Unordered list item (`- `, `* `) | 5 |
| Ordered list item (`1. `, `2. `) | 5 |
| Newline | 1 |

Code fences are never split. Break scores decay quadratically with distance from the ideal split point (decay factor 0.7).

Search matches point to the chunk, not the exact line. To narrow down after finding the right document, use `get` with `fromLine` and `maxLines` parameters.

## Latency Expectations

| Tool | Typical Latency | Notes |
|------|----------------|-------|
| `search` | ~30ms | BM25 only, no model inference |
| `vector_search` | ~2s | Embedding + vector lookup + optional expansion |
| `deep_search` | ~10s | Full pipeline: expansion + BM25 + vector + reranking |

First query is slower while models load into VRAM. Use MCP HTTP daemon mode (`qmd mcp --http --daemon`) to keep models warm between requests (~16s → ~10s).

## BM25 Scoring

FTS5 columns: filepath (10x weight), title (1x), body (1x). Uses Porter stemmer + Unicode 6.1 tokenizer. Score normalization: Sigmoid `1/(1+exp(-(|x|-5)/3))` maps raw BM25 scores to 0-1 range.

## GGUF Models

| Model | Purpose | Size | Notes |
|-------|---------|------|-------|
| `embeddinggemma-300M` (Q8_0) | Vector embeddings | ~300MB (300M params) | Google EmbeddingGemma, from `ggml-org/embeddinggemma-300M-GGUF` |
| `qwen3-reranker-0.6b` (Q8_0) | Cross-encoder re-ranking | ~640MB (600M params) | From `ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF` |
| `qmd-query-expansion-1.7B` (Q4_K_M) | Query expansion | ~1.1GB (GRPO fine-tuned from Qwen3-1.7B) | From `tobil/qmd-query-expansion-1.7B-gguf` |

Models are cached in `~/.cache/qmd/models/`. Auto-downloaded on first use via node-llama-cpp, or manually via `qmd pull [--refresh]`. GPU parallelism (multiple LlamaContext instances) is used when available for faster embedding and reranking — up to 2.7x speedup.

## Constants

```
STRONG_SIGNAL_MIN_SCORE = 0.85
STRONG_SIGNAL_MIN_GAP = 0.15
RERANK_CANDIDATE_LIMIT = 40
CHUNK_SIZE_TOKENS = 900
CHUNK_OVERLAP_TOKENS = 135 (15%)
CHUNK_WINDOW_TOKENS = 200
```

Note: RRF k=60 is a default parameter in `reciprocalRankFusion(lists, weights, k=60)`, not a named constant.

## Query Expansion Grammar

The expansion model is constrained to output in this grammar:

```
root ::= line+
line ::= type ": " content "\n"
type ::= "lex" | "vec" | "hyde"
content ::= [^\n]+
```

Validation: each expanded query must contain at least one term from the original. Fallback on failure: `[{type: 'vec', text: originalQuery}]`.

## Embedding Text Format

- **Queries:** `task: search result | query: {query}` (nomic-style task prefix)
- **Documents:** `title: {title} | text: {text}`

## Session Timeouts

- `query`/`vsearch`: 10-minute LLM session timeout
- `embed`: 30-minute session timeout (for large collections)
- MCP: models stay loaded, contexts disposed after 5-minute inactivity

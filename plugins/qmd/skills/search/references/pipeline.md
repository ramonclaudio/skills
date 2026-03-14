# QMD Hybrid Pipeline Internals

## Query Expansion

The hybrid pipeline uses a GRPO-optimized query expansion model (fine-tuned from Qwen3-1.7B with Group Relative Policy Optimization) to generate 3 types of sub-queries:

| Type | Purpose | Routed to | Example for "auth middleware" |
|------|---------|-----------|-------------------------------|
| `lex` | Keyword variants | BM25 only | "authentication middleware handler" |
| `vec` | Semantic rephrasing | Vector only | "how request authentication is validated" |
| `hyde` | Hypothetical document | Vector only | "The middleware checks the JWT token and attaches the user to the request context" |

Each sub-query is type-routed to the appropriate backend: `lex` queries run BM25 keyword search only, `vec` and `hyde` queries run vector search only. This eliminates wasted backend calls (~10 → 6 per query).

Expansion is conditional. When the BM25 probe returns a strong signal (top score >= 0.85 AND gap to second result >= 0.15), expansion is skipped entirely to save compute.

Note: `qmd vsearch` also uses query expansion internally, filtered to `vec` and `hyde` types only (no `lex`). The full query pipeline (`qmd query` CLI) isn't the only path that expands queries. MCP `query` only accepts `lex`, `vec`, `hyde` types. The `expand:` type and plain text auto-expansion are CLI-only.

### Query Document Format

Queries can be submitted as multi-line **query documents** with typed sub-queries. Each line has an optional type prefix (`lex:`, `vec:`, `hyde:`). The CLI also supports `expand:` and plain text (implicit `expand:`), which auto-expand via the local LLM. MCP only accepts `lex`, `vec`, `hyde` types.

The first sub-query in the document receives **2x weight** in RRF fusion, so put the most important query first.

Only one `expand:` line is allowed per query document (explicit or implicit).

**Examples:**

Single-line (unchanged behavior, implicit `expand:`):
```
auth middleware JWT validation
```

Multi-line with typed sub-queries:
```
lex: "JWT validation" middleware -session
vec: how does the auth middleware verify tokens
hyde: The middleware extracts the Bearer token from the Authorization header and verifies it using jsonwebtoken
```

Mixed: first line is high-priority, rest are supplementary:
```
lex: "C++ performance" optimization -sports -athlete
vec: techniques to optimize C++ code for speed
expand: C++ profiling and bottleneck detection
```

### Lex Syntax

`lex:` sub-queries support BM25 operators for precise keyword control:

| Operator | Syntax | Behavior | Example |
|----------|--------|----------|---------|
| Phrase | `"exact phrase"` | Verbatim match, no prefix matching | `"JWT validation"` matches "JWT validation" but not "JWT validator" |
| Negation (word) | `-term` | Exclude documents containing term | `-session` |
| Negation (phrase) | `-"exact phrase"` | Exclude documents containing phrase | `-"session cookie"` |
| Word | bare word | Standard BM25 keyword match (with stemming) | `middleware` |

Negations are useful for disambiguation, e.g., `"python" web framework -snake -reptile` to search for the programming language.

## RRF Fusion

Results from all search backends are fused with Reciprocal Rank Fusion (RRF, k=60). The first two result lists (original BM25 results + original vector results) get 2x weight; expanded query results get 1x weight. When using query documents, the first sub-query's results also get 2x weight in fusion.

Top-rank bonuses are applied after RRF:
- Rank 0 (top result): +0.05
- Ranks 1-2: +0.02

After fusion, the top 40 candidates (RERANK_CANDIDATE_LIMIT) pass to the reranker.

## Reranking

For each candidate document, the pipeline picks the single best chunk (by keyword overlap with the query) and sends only that chunk to the LLM cross-encoder reranker. There is no multi-chunk score aggregation. One chunk per document.

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
| H4 | 70 |
| Code block | 80 |
| H5 | 60 |
| H6 | 50 |
| Horizontal rule | 60 |
| Blank line (paragraph boundary) | 20 |
| Unordered list item (`- `, `* `) | 5 |
| Ordered list item (`1. `, `2. `) | 5 |
| Newline | 1 |

Code fences are never split. Break scores decay quadratically with distance from the ideal split point (decay factor 0.7).

Search matches point to the chunk, not the exact line. To narrow down after finding the right document, use `get` with `fromLine` and `maxLines` parameters.

## Latency Expectations

| Approach | CLI Command | MCP Sub-query | Typical Latency | Notes |
|----------|-------------|---------------|----------------|-------|
| BM25 keyword | `qmd search` | `lex:` | ~30ms | No model inference |
| Vector search | `qmd vsearch` | `vec:`/`hyde:` | ~2s | Embedding + vector lookup + optional expansion |
| Full hybrid | `qmd query` | `lex`+`vec`+`hyde` (CLI also: `expand:`) | ~10s | Expansion + BM25 + vector + reranking |

First query is slower while models load into VRAM. Use MCP HTTP daemon mode (`qmd mcp --http --daemon`) to keep models warm between requests (~16s → ~10s).

## BM25 Scoring

FTS5 columns: filepath (10x weight), title (1x), body (1x). Uses Porter stemmer + Unicode 6.1 tokenizer. Score normalization: `|x| / (1 + |x|)` maps raw BM25 scores to 0-1 range (e.g., strong(-10) → 0.91, medium(-2) → 0.67, weak(-0.5) → 0.33).

## GGUF Models

| Model | Purpose | Size | Notes |
|-------|---------|------|-------|
| `embeddinggemma-300M` (Q8_0) | Vector embeddings | ~300MB (300M params) | Google EmbeddingGemma, from `ggml-org/embeddinggemma-300M-GGUF` |
| `qwen3-reranker-0.6b` (Q8_0) | Cross-encoder re-ranking | ~640MB (600M params) | From `ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF` |
| `qmd-query-expansion-1.7B` (Q4_K_M) | Query expansion | ~1.1GB (GRPO fine-tuned from Qwen3-1.7B) | From `tobil/qmd-query-expansion-1.7B-gguf` |

Models are cached in `~/.cache/qmd/models/`. Auto-downloaded on first use via node-llama-cpp, or manually via `qmd pull [--refresh]`. GPU parallelism (multiple LlamaContext instances) is used when available for faster embedding and reranking, up to 2.7x speedup.

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

The expansion model is constrained to output in this grammar (EBNF):

```
query_document = { line } ;
line           = [ type ":" ] text newline ;
type           = "lex" | "vec" | "hyde" | "expand" ;   # expand is CLI-only
```

Lines without a type prefix are treated as implicit `expand:` (auto-expanded by the local LLM). At most one `expand:` line per query document. MCP `query` only accepts `lex`, `vec`, `hyde`.

### Lex Query Sub-Grammar

`lex:` lines support structured BM25 operators:

```
lex_query   = { lex_term } ;
lex_term    = negation | phrase | word ;
negation    = "-" ( phrase | word ) ;
phrase      = '"' { character } '"' ;
word        = { letter | digit | "'" } ;
```

Phrases use verbatim matching (no prefix matching or stemming). Bare words use standard BM25 matching with Porter stemming.

Validation: each expanded query must contain at least one term from the original. Fallback on failure: `[{type: 'vec', text: originalQuery}]`.

## Embedding Text Format

- **Queries:** `task: search result | query: {query}` (nomic-style task prefix)
- **Documents:** `title: {title} | text: {text}`

## Session Timeouts

- `query`/`vsearch`: 10-minute LLM session timeout
- `embed`: 30-minute session timeout (for large collections)
- MCP: models stay loaded, contexts disposed after 5-minute inactivity

# QMD Hybrid Pipeline Internals

## Intent (Disambiguation)

Available since upstream 1.1.5. Pass `intent` to steer ambiguous queries without searching on it. Affects 5 stages of the pipeline:

1. **Expansion**: the LLM prompt includes `Query intent: {intent}` so generated lex/vec/hyde variants align with the domain.
2. **Strong-signal bypass**: skipped when intent is set (the obvious BM25 match may not be what you want).
3. **Chunk selection**: intent terms are scored at 0.5x weight alongside query terms (1.0x) when picking the best chunk per document.
4. **Reranking**: intent is prepended to the rerank query so Qwen3-Reranker scores with domain context.
5. **Snippet extraction**: intent terms scored at 0.3x weight to nudge snippets toward intent-relevant lines.

CLI: `--intent <text>` flag or `intent:` line in a query document. MCP: `intent` parameter on the `query` tool. At most one `intent:` line per query document, and it cannot appear alone (must accompany at least one `lex:`/`vec:`/`hyde:` line).

Without intent, "performance" is ambiguous (web-perf? team health? fitness?). With `intent: "web page load times and Core Web Vitals"`, the pipeline preferentially expands, ranks, and snippets web-perf content.

## Two Pipeline Paths

QMD has two entry points into the hybrid pipeline:

| Function | Caller | Behavior |
|----------|--------|----------|
| `hybridQuery()` | `qmd query "plain text"` | Runs the local 1.7B expansion model first, then BM25 + vector + RRF + rerank. ~10s. |
| `structuredSearch()` | `qmd query $'lex: ...\nvec: ...'` and the **MCP `query` tool** | Skips expansion entirely. The caller provides typed sub-queries. ~3-8s. |

Both paths converge after step 2. The MCP server always uses `structuredSearch` because the LLM caller (you, in Claude Code) is expected to do the expansion. This is why composing good `lex:`/`vec:`/`hyde:` sub-queries matters more from MCP than from the bare CLI.

## Query Expansion (CLI plain-text only)

The hybrid pipeline (`hybridQuery`) uses a GRPO-optimized query expansion model (fine-tuned from Qwen3-1.7B with Group Relative Policy Optimization) to generate 3 types of sub-queries:

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

The reranker uses node-llama-cpp's `createRankingContext()` and `rankAndSort()` API with a **4096-token context window** (configurable via `QMD_RERANK_CONTEXT_SIZE`) and flash attention enabled. Template overhead is **512 tokens** (raised from 200 in upstream 2.1.0). Document chunks get the remaining `RERANK_CONTEXT_SIZE - 512 - queryTokens`.

**Skipping the reranker:** Pass `--no-rerank` (CLI) or `rerank: false` (MCP `query` tool) to return RRF-fused scores only. Much faster on CPU-only machines.

**Tuning candidate count:** `-C` / `--candidate-limit` (CLI) or `candidateLimit` (MCP). Default 40. Lower = faster, may miss results.

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

Since qmd 2.5.0, search results return an absolute source-file `line` (no longer chunk-local), so a hit's `line` can be passed straight to `get` as `fromLine`. The snippet still scopes to the best matching chunk (~900 tokens); widen with `maxLines` for surrounding context.

### AST-Aware Chunking (`--chunk-strategy auto`)

Added in upstream 2.1.0. For supported code files, QMD parses the source with `web-tree-sitter` and adds AST-derived breakpoints that merge with the regex breakpoint scores above:

| AST Node | Score | Languages |
|----------|-------|-----------|
| Class / interface / struct / impl / trait | 100 | All |
| Function / method | 90 | All |
| Type alias / enum | 80 | All |
| Import / use declaration | 60 | All |

Supported file extensions: `.ts`, `.tsx`, `.js`, `.jsx`, `.mts`, `.cts`, `.mjs`, `.cjs`, `.py`, `.go`, `.rs`. Markdown and unknown file types always use regex chunking regardless of `--chunk-strategy`.

The flag is exposed on both `qmd embed` (chunks at index time) and `qmd query` (chunks at retrieval time). Both should use the same strategy. Tree-sitter grammars are optional; missing grammars fall back to regex.

## Score Traces (`--explain`)

Added in upstream 1.1.2. `qmd query --explain` (and the `--json --explain` combo) emits per-result score traces so you can see exactly why each result ranked where it did:

- `ftsScores`: BM25 score per query variant
- `vectorScores`: vector cosine score per query variant
- `rrf.contributions`: per-list RRF contribution
- `rrf.totalScore` / `rrf.baseScore` / `rrf.topRankBonus`: fused RRF score breakdown
- `rerankScore`: raw reranker output (0-1)
- `blendedScore` and `rrf.weight`: position-aware blend (e.g. `75%*0.33 + 25%*0.81 = 0.45`)

Useful for debugging surprising rankings, A/B testing config changes, and understanding what `--no-rerank` would do.

## Latency Expectations

| Approach | CLI Command | MCP Sub-query | Typical Latency | Notes |
|----------|-------------|---------------|----------------|-------|
| BM25 keyword | `qmd search` | `lex:` | ~30ms | No model inference |
| Vector search | `qmd vsearch` | `vec:`/`hyde:` | ~2s | Embedding + vector lookup + optional expansion |
| Full hybrid | `qmd query` | `lex`+`vec`+`hyde` (CLI also: `expand:`) | ~10s | Expansion + BM25 + vector + reranking |

First query is slower while models load into VRAM. The MCP HTTP daemon (`qmd mcp --http --daemon`) keeps models warm as long as queries arrive within the 5-min idle window — but the SDK forces `disposeModelsOnInactivity: true`, so a fully-idle daemon will pay the cold-start cost on the next request.

## BM25 Scoring

FTS5 columns: filepath (10x weight), title (1x), body (1x). Uses Porter stemmer + Unicode 6.1 tokenizer. Score normalization: `|x| / (1 + |x|)` maps raw BM25 scores to 0-1 range (e.g., strong(-10) → 0.91, medium(-2) → 0.67, weak(-0.5) → 0.33).

## GGUF Models

| Model | Purpose | Size | Notes |
|-------|---------|------|-------|
| `embeddinggemma-300M` (Q8_0) | Vector embeddings | ~300MB (300M params) | Google EmbeddingGemma, from `ggml-org/embeddinggemma-300M-GGUF` |
| `qwen3-reranker-0.6b` (Q8_0) | Cross-encoder re-ranking | ~640MB (600M params) | From `ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF` |
| `qmd-query-expansion-1.7B` (Q4_K_M) | Query expansion | ~1.1GB (GRPO fine-tuned from Qwen3-1.7B) | From `tobil/qmd-query-expansion-1.7B-gguf` |

Models are cached in `${XDG_CACHE_HOME:-~/.cache}/qmd/models/`. Auto-downloaded on first use via node-llama-cpp, or manually via `qmd pull [--refresh]`. GPU parallelism (multiple LlamaContext instances) is used when available for faster embedding and reranking, up to 2.7x speedup. Override the GPU backend with `QMD_LLAMA_GPU=cuda|metal|vulkan|cpu`.

## Constants

```
STRONG_SIGNAL_MIN_SCORE  = 0.85
STRONG_SIGNAL_MIN_GAP    = 0.15
RERANK_CANDIDATE_LIMIT   = 40    (override: -C / --candidate-limit / candidateLimit)
RERANK_CONTEXT_SIZE      = 4096  (override: QMD_RERANK_CONTEXT_SIZE)
RERANK_TEMPLATE_OVERHEAD = 512
EMBED_CONTEXT_SIZE       = 2048  (override: QMD_EMBED_CONTEXT_SIZE)
EXPAND_CONTEXT_SIZE      = 2048  (override: QMD_EXPAND_CONTEXT_SIZE)
CHUNK_SIZE_TOKENS        = 900
CHUNK_OVERLAP_TOKENS     = 135   (15%)
CHUNK_WINDOW_TOKENS      = 200
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

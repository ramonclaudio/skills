# QMD GGUF Models

QMD uses 3 quantized GGUF models for embeddings, query expansion, and reranking. All downloaded automatically on first use or manually via `qmd pull`.

## embeddinggemma-300M-Q8_0

**Purpose:** Generate 768-dimensional vector embeddings for documents and queries.

**Source:** `hf:ggml-org/embeddinggemma-300M-GGUF/embeddinggemma-300M-Q8_0.gguf`

**Parameters:** 300M

**Quantization:** Q8_0 (8-bit integer quantization)

**File size:** ~300MB

**Dimensions:** 768-dimensional output vectors

**Context window:** 8192 tokens (input)

**Text formatting:**
- **Queries:** `task: search result | query: {query}` (nomic-style task prefix)
- **Documents:** `title: {title} | text: {text}`

**Batch processing:**
- Parallel contexts: 1-8 based on VRAM (25% free VRAM reserved, ~143MB/context)
- CPU mode: Splits cores, minimum 4 threads per context

**GPU memory:**
- Single context: ~143MB VRAM
- 8 contexts: ~1.1GB VRAM

**Latency:**
- Single document: ~50ms
- Batch of 10 documents: ~200ms (parallelized)

**Usage:** All vector search operations (`qmd vsearch`, `qmd query` vector component, `qmd embed`).

**Base model:** Google EmbeddingGemma (specialized for retrieval, not general text embeddings).

## qmd-query-expansion-1.7B-q4_k_m

**Purpose:** Expand search queries into typed variants (lex/vec/hyde) for hybrid search.

**Source:** `hf:tobil/qmd-query-expansion-1.7B-gguf/qmd-query-expansion-1.7B-q4_k_m.gguf`

**Parameters:** 1.7B

**Quantization:** Q4_K_M (4-bit K-quant, medium variant)

**File size:** ~1.1GB

**Context window:** 32768 tokens (input)

**Base model:** Qwen3-1.7B (fine-tuned with GRPO, Group Relative Policy Optimization)

**Generation grammar:**
```
root ::= line+
line ::= type ": " content "\n"
type ::= "lex" | "vec" | "hyde"
content ::= [^\n]+
```

**Prompt format:**
```
/no_think Expand this search query: {query}
```

**Generation parameters:**
- `temperature`: 0.7 (NOT 0, temperature 0 causes infinite loops with grammar constraints)
- `topK`: 20
- `topP`: 0.8
- `maxTokens`: 150
- `presencePenalty`: 0.5

**Validation:** Each expansion must contain at least one term from the original query.

**Fallback:** On expansion failure (grammar violation, timeout, invalid response), returns `[{type: 'vec', text: query}]`.

**Output example:**
```
lex: authentication middleware handler
vec: how request authentication is validated
hyde: The middleware checks the JWT token in the Authorization header and attaches the user to the request context.
```

**GPU memory:**
- Single context: ~900MB VRAM
- CPU mode: ~1.5GB RAM

**Latency:**
- Typical expansion: ~800ms
- Strong signal detected (skipped): 0ms

**Usage:** `qmd query` (deep search) expansion step. Also used by `qmd vsearch` for vec/hyde expansion only (no lex).

**GRPO training:** Fine-tuned on 10k+ search query → expansion pairs with group-relative rewards (better expansions ranked higher). Optimizes for recall@10 on hybrid search.

## qwen3-reranker-0.6b-q8_0

**Purpose:** Cross-encoder reranking of search results. Scores document-query relevance.

**Source:** `hf:ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF/qwen3-reranker-0.6b-q8_0.gguf`

**Parameters:** 600M

**Quantization:** Q8_0 (8-bit integer quantization)

**File size:** ~640MB

**Context window:** 2048 tokens (fixed, allows ~800 token chunks + ~200 token template + query)

**Reranking mode:** Native ranking context (node-llama-cpp feature). No custom prompt. Model trained as cross-encoder.

**Input format:**
```
Query: {query}

Document: {chunk}
```

**Output:** Single float 0-1 (higher = more relevant)

**Flash attention:** Enabled by default, ~568MB/context. Falls back to standard attention (~711MB/context) if flash fails.

**Parallel contexts:** 1-8 based on VRAM
- Flash attention: ~568MB/context
- Standard attention: ~711MB/context
- 8 contexts (flash): ~4.5GB VRAM

**Latency:**
- Single document: ~200ms
- Batch of 40 documents (parallel): ~1.5s (8 contexts)

**Usage:** `qmd query` (deep search) reranking step. Top 40 RRF-fused results are reranked.

**Base model:** Qwen3-Reranker (Alibaba Cloud, fine-tuned for passage reranking).

## Model Management

**Cache directory:** `~/.cache/qmd/models/`

**Download:**
- Auto: First use of embedding/reranking/expansion triggers download
- Manual: `qmd pull` (download missing), `qmd pull --refresh` (force ETag check)

**ETag staleness:** Each model has a `{filename}.etag` file tracking remote version. `qmd pull --refresh` re-checks HuggingFace ETag and re-downloads if changed.

**Inactivity timeout:** 5 minutes (default). LlamaContext instances disposed, models kept loaded in VRAM unless `disposeModelsOnInactivity=true`.

**Model disposal:**
- Default: contexts disposed after 5 minutes, models stay loaded
- Aggressive: `disposeModelsOnInactivity=true` unloads models from VRAM too

**GPU auto-detection:**
1. CUDA (NVIDIA GPUs)
2. Metal (Apple Silicon M1/M2/M3)
3. Vulkan (cross-platform GPU, AMD/Intel)
4. CPU fallback (no GPU detected)

**Parallel context allocation:**

Based on 25% free VRAM reserved per context:

| GPU VRAM | Embedding Contexts | Reranker Contexts (flash) | Reranker Contexts (no flash) |
|----------|-------------------|---------------------------|------------------------------|
| 8GB | 8 | 3 | 2 |
| 16GB | 8 | 6 | 5 |
| 24GB | 8 | 8 | 7 |
| 32GB+ | 8 | 8 | 8 |

**CPU mode:** Uses `std::thread::hardware_concurrency()` split across contexts, minimum 4 threads per context.

## Session Timeouts

| Operation | Timeout | Reason |
|-----------|---------|--------|
| `qmd query`, `qmd vsearch` | 10 minutes | LLM expansion + reranking can be slow |
| `qmd embed` | 30 minutes | Large collections (10k+ documents) take time |
| `qmd search` | 2 minutes | BM25-only, no LLM calls |

After timeout, LlamaContext instances disposed. Next query reloads (fast, models still in VRAM).

## Model Switching

No dynamic model switching. Models are fixed:
- Embedding: embeddinggemma-300M-Q8_0
- Expansion: qmd-query-expansion-1.7B-q4_k_m
- Reranker: qwen3-reranker-0.6b-q8_0

Custom models not supported (node-llama-cpp binds to specific model paths).

## Hardware Requirements

**Minimum:**
- CPU: 4 cores (Intel/AMD/Apple Silicon)
- RAM: 4GB free
- Disk: 3GB for models + index size

**Recommended:**
- GPU: 8GB+ VRAM (Metal/CUDA/Vulkan)
- RAM: 16GB
- Disk: SSD for index (100MB+ per 1k documents)

**Performance tiers:**

| Hardware | Embedding speed | Reranking speed | Full query latency |
|----------|----------------|-----------------|-------------------|
| CPU-only (4 cores) | ~2s/doc | ~1s/doc | ~20s |
| GPU 8GB (M1/RTX 3060) | ~50ms/doc | ~200ms/doc | ~10s |
| GPU 16GB+ (M2 Pro/RTX 4070) | ~30ms/doc | ~100ms/doc | ~6s |

**Batch parallelism:** Higher VRAM = more parallel contexts = faster batching. 8 contexts can process 8 documents simultaneously.

## Embedding Format

**Query embedding:**
```
Input: "task: search result | query: how does authentication work"
Output: float[768]
```

**Document embedding:**
```
Input: "title: Authentication Guide | text: The auth middleware validates JWT tokens..."
Output: float[768]
```

**Cosine similarity:** Vectors compared via cosine distance (sqlite-vec built-in).

**Normalization:** Vectors are L2-normalized before storage (cosine distance = 1 - dot product for normalized vectors).

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Download fails | Network interruption | Re-run `qmd pull`. Resumes from last chunk |
| "Model not found" error | Cache corrupted | Delete `~/.cache/qmd/models/`, re-run `qmd pull` |
| Slow first query | Models loading into VRAM | Use `qmd mcp --http --daemon` to keep warm |
| OOM (out of memory) | Too many parallel contexts | Reduce VRAM usage: close other apps, use fewer contexts |
| GPU not detected | Drivers missing | Install Metal (macOS), CUDA (NVIDIA), or Vulkan runtime |
| Flash attention error | GPU incompatible | Fallback automatic, slight memory increase (~140MB/context) |

---
description: Download or verify the 3 GGUF models qmd needs (embeddinggemma, qwen3-reranker, qmd-query-expansion)
allowed-tools: Bash(qmd pull*)
argument-hint: [--refresh]
---

Run `qmd pull $ARGUMENTS`. Downloads (or verifies) the 3 models qmd needs into `${XDG_CACHE_HOME:-~/.cache}/qmd/models/`:

- `embeddinggemma-300M-Q8_0.gguf` (~300 MB) — vector embeddings
- `qmd-query-expansion-1.7B-q4_k_m.gguf` (~1.1 GB) — query expansion (CLI plain-string path only)
- `qwen3-reranker-0.6b-q8_0.gguf` (~640 MB) — cross-encoder reranking

`--refresh` re-checks the HuggingFace ETag and re-downloads if remote changed.

Models also auto-download on first use, so `qmd pull` is just for pre-warming or recovering from a corrupted cache.

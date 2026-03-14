---
description: Download or verify QMD GGUF models from HuggingFace
allowed-tools: Bash(qmd pull*)
argument-hint: [--refresh]
---

Run `qmd pull` (or `qmd pull --refresh` if user asks to re-download).

`--refresh`: Re-download models even if already cached (checks ETag for staleness).

Downloads 3 GGUF models to `~/.cache/qmd/models/`:
1. embeddinggemma-300M-Q8_0.gguf (~300MB): vector embeddings (768 dimensions)
2. qmd-query-expansion-1.7B-q4_k_m.gguf (~1.1GB): custom GRPO fine-tuned query expansion
3. qwen3-reranker-0.6b-q8_0.gguf (~640MB): cross-encoder reranking

Reports per model: name, path, size, status (cached/checked or refreshed).

Total: ~2GB download on first run.

Models are auto-downloaded on first embed/search, but `qmd pull` lets you pre-download.

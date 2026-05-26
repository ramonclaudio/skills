---
description: Diagnose qmd index and runtime health: SQLite and sqlite-vec versions, model cache, the GPU device probe, and embedding fingerprint freshness. Run first when search misbehaves or after upgrading qmd.
allowed-tools: Bash(qmd doctor*)
---

Run `qmd doctor`. It reports:

- SQLite, `better-sqlite3`, and `sqlite-vec` versions
- Index config: collection count, model defaults, environment overrides
- Model cache: whether the embedding, rerank, and generate GGUFs are present and valid
- Device: GPU backend (Metal, CUDA, or Vulkan), offloading, VRAM, and CPU math cores
- Embedding freshness: whether active docs match the current embedding fingerprint
- Embedding vector sample: whether stored vectors still reproduce under the current pipeline

Act on the result, do not just dump it:

- Invalid or missing model cache: run `/qmd:pull` (or `qmd pull --refresh`).
- Stored vectors no longer reproduce, or mixed fingerprints reported: run `/qmd:embed --force` to rebuild the whole vector space, since the model or chunking changed.
- Pending embeds: run `/qmd:embed`.

`qmd doctor` is the first thing to run when `qmd query` or `vsearch` returns nothing or errors. It isolates model, GPU, and index problems before you touch config. GPU diagnostics live here, not in `/qmd:status`, as of qmd 2.5.0.

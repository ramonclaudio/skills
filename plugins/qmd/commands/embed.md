---
description: Generate or refresh vector embeddings for indexed documents
allowed-tools:
  - Bash(qmd embed*)
  - Bash(qmd status*)
argument-hint: [-f|--force]
---

Run `qmd embed` (or `qmd embed -f` if user passes --force or -f).

`-f` / `--force`: Clear all existing vectors and re-embed everything from scratch.

What it does:
- Finds documents needing embeddings
- Chunks them (900 tokens with 15% overlap, markdown-aware break points)
- Embeds in batches of 32 via embeddinggemma-300M
- Shows progress bar with throughput and ETA

First run downloads the embedding model (~300MB) if not cached.

After embed completes, run `qmd status` to confirm zero pending embeddings.

If interrupted: safe to re-run, picks up where it left off (only embeds hashes without vectors).

Force re-embed use cases: after model update, corrupted embeddings, switching embedding models.

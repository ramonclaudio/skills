---
description: Clear qmd LLM cache, remove orphaned vectors and inactive docs, and vacuum the SQLite index
allowed-tools: Bash(qmd cleanup*)
---

Run `qmd cleanup`. It runs 4 steps:

1. Clear LLM cache (cached query expansion + reranking results)
2. Remove orphaned vector embeddings (skipped gracefully if sqlite-vec is unavailable)
3. Delete inactive (soft-deleted) document records
4. SQLite VACUUM to reclaim disk space

Report the counts from each step. Searches will be slower for the first few queries after cleanup until the LLM cache rebuilds naturally.

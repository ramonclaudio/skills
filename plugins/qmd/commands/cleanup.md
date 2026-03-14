---
description: Clear QMD caches, remove orphaned data, vacuum database
allowed-tools: Bash(qmd cleanup*)
---

Run `qmd cleanup`. This performs 4 steps sequentially:

1. Delete all LLM cache entries from the llm_cache table (cached query expansion and reranking results from previous searches). Reports count cleared
2. Remove orphaned vectors (embeddings with no corresponding document reference, vectors for deleted or changed documents). Reports count removed or "No orphaned embeddings to remove"
3. Delete inactive documents (records with active=0, soft-deleted during indexing when files are removed or modified). Reports count removed if > 0
4. Run SQLite VACUUM to reclaim disk space from deleted records. Reports "Database vacuumed"

Each step shows a green checkmark on completion. Note that searches will be slower after cleanup until the LLM cache rebuilds through natural query usage.

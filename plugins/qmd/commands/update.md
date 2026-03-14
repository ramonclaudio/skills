---
description: Update and re-index all QMD collections
allowed-tools:
  - Bash(qmd update*)
  - Bash(qmd embed*)
---

Run `qmd update && qmd embed`. Report any collections whose update command failed.

`qmd update` always updates ALL collections. There is no argument to target a single collection.

`--pull` appears in `qmd --help` output but is a dead flag. Defined in the CLI parser but never actually used. Update commands configured in YAML always run regardless of this flag.

Pipeline:
1. Clear LLM cache (entire `llm_cache` table wiped)
2. For each collection sequentially:
   a. Execute update command (if configured in YAML, e.g. `git pull --ff-only`)
   b. Index files matching the collection's glob pattern
   c. Report indexed/updated/unchanged/removed counts
   d. Clean orphaned content hashes
3. Post-check: warns if documents need embedding, suggests `qmd embed`

If any collection's update command exits non-zero, `qmd update` calls `process.exit(exitCode)` immediately. Remaining collections are NOT processed. There is no `--continue-on-error` flag.

If the user asks to force re-embed everything (e.g., after model changes or corrupted embeddings), run `qmd embed -f` (separate from update).

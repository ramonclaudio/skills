---
description: Pull all indexed repos, re-index, re-embed
allowed-tools: Bash(qmd *)
argument-hint: [collection-name]
---

Run `qmd update && qmd embed`. Report any collections whose update command failed.

Each collection's `update` field in `~/.config/qmd/index.yml` (e.g., `git pull --ff-only`) is executed during `qmd update` before re-indexing.

If the user asks to force re-embed everything (e.g., after model changes or corrupted embeddings), run `qmd embed -f` instead of `qmd embed`.

---
description: Pull all reference repos, re-index changed files, and embed new content. Long running.
allowed-tools:
  - Bash(qmd update*)
  - Bash(qmd embed*)
---

Run `qmd update && qmd embed`. Report:

- Per-collection update command output (usually `git pull --ff-only`)
- Indexed/updated/unchanged/removed counts
- Embedding progress and final pending count

Notes:
- `qmd update` always processes ALL collections (no per-collection flag).
- If any collection's update command exits non-zero, `qmd update` exits immediately and skips remaining collections. Report the failing collection so the user can fix and re-run.
- The `--pull` flag in `qmd --help` is dead (parser-only, never read). Update commands come from each collection's YAML `update:` field.
- For force re-embed (after model change or corruption), suggest `/qmd:embed --force`.

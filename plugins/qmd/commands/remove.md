---
description: Remove a collection from the qmd index (does not delete the underlying repo on disk)
allowed-tools: Bash(qmd collection remove*)
argument-hint: <collection-name>
---

Run `qmd collection remove $ARGUMENTS`. This:

1. Removes the collection from `~/.config/qmd/index.yml`
2. Deletes all document records for that collection from the SQLite index
3. Cleans up orphaned content hashes (content rows no longer referenced)

Report counts of deleted documents and cleaned content hashes.

**Do NOT delete the cloned repo at `~/Developer/refs/<name>` unless the user explicitly asks.** If they do, use `trash`, never `rm`.

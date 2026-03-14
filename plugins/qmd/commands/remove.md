---
description: Remove a collection from the QMD index
allowed-tools: Bash(qmd collection remove*)
argument-hint: <collection-name>
---

Run `qmd collection remove $ARGUMENTS` (alias: `qmd collection rm`). This:

1. Validates collection exists in YAML config first
2. Removes collection from ~/.config/qmd/index.yml
3. Deletes all document records from DB for that collection
4. Cleans up orphaned content hashes (content entries with no remaining document references)

Reports count of deleted documents and cleaned content hashes.

NEVER delete the repo from ~/Developer/refs/ unless user explicitly asks. If they do, use `trash`, never `rm`.

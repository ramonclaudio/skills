---
description: List QMD collections or files within a collection
allowed-tools: Bash(qmd ls*)
argument-hint: [collection/path]
---

Run `qmd ls $ARGUMENTS`.

- No arguments: lists all collections with document count
- With collection name: lists files in that collection with ls -l style output (size in B/KB/MB/GB padded, date as "MMM DD HH:MM" or "MMM DD YYYY" if >6 months old, virtual path with colored filename)
- With collection/path prefix: lists files under that prefix (e.g., `qmd ls next.js/packages`)
- Supports `qmd://` URIs: `qmd ls qmd://next.js/packages`

Output uses color coding by file type. If the collection is not found, suggest running `/qmd:status` to see available collections.

Note: Both `qmd ls` and `qmd collection list` read from YAML config and database. `qmd ls` shows ls-style file listings within collections. `qmd collection list` shows collection metadata (path, pattern, counts).

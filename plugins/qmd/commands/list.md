---
description: List QMD collections or files within a collection
disable-model-invocation: true
---

Run `qmd ls $ARGUMENTS`.

- No arguments: lists all collections with `qmd://` URIs.
- With collection name: lists files in that collection (e.g., `qmd ls next.js`).
- With path prefix: lists files under that prefix (e.g., `qmd ls next.js/packages`).
- Supports `qmd://` URIs: `qmd ls qmd://next.js/packages`.

If the collection is not found, suggest running `/qmd:status` to see available collections.

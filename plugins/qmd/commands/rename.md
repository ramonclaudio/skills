---
description: Rename a QMD collection
allowed-tools: Bash(qmd collection rename*)
argument-hint: <old-name> <new-name>
---

Run `qmd collection rename $ARGUMENTS` (alias: `qmd collection mv`). Expects two arguments: `<old-name> <new-name>`.

This validates and syncs:
1. Validates old collection name exists in YAML
2. Validates new name doesn't already exist
3. Validates new name matches `[a-zA-Z0-9_-]+` regex
4. Updates YAML config (collection key renamed)
5. Updates all documents.collection in DB
6. Updates all virtual paths (qmd:// URIs in documents table)

Reports old and new qmd:// URIs. Warns if any scripts, contexts, or commands reference the old collection name.

Errors: old name not found → exit 1, new name already exists → exit 1.

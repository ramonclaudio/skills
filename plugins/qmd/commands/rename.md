---
description: Rename a qmd collection. Updates YAML config, all document records, and all virtual paths.
allowed-tools: Bash(qmd collection rename*)
argument-hint: <old-name> <new-name>
---

Run `qmd collection rename $ARGUMENTS` (alias: `qmd collection mv`). Expects two positional arguments.

What it touches:

1. Validates the old collection name exists in YAML
2. Validates the new name doesn't already exist in YAML
3. Renames the collection key in `${XDG_CONFIG_HOME:-~/.config}/qmd/index.yml`
4. Updates `documents.collection` for every row in the SQLite index
5. Rewrites every `qmd://<old>/...` virtual path in the documents table to `qmd://<new>/...`

Reports the old and new `qmd://` URIs.

Errors:
- Old name not found → exits non-zero
- New name already exists → exits non-zero

Note: the rename CLI does NOT validate that the new name matches the standard `[a-zA-Z0-9_-]+` pattern (the validation function exists but isn't called from rename). If you pass a name with special characters, the rename will succeed but downstream commands and virtual paths may misbehave. Stick to lowercase letters, numbers, hyphens, and underscores.

After renaming, warn the user that any external scripts, hardcoded `update-cmd` shell commands, or context entries referencing the old `qmd://<old>/` URIs or paths will need to be updated by hand. The rename only fixes qmd's internal state.

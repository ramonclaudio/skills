---
description: Show YAML config for a single qmd collection (path, pattern, include state, update command, context count).
allowed-tools: Bash(qmd collection show*)
argument-hint: <name>
---

Run `qmd collection show $ARGUMENTS` (alias: `qmd collection info`). Prints the YAML-side fields for one collection:

- `Path` — on-disk root
- `Pattern` — file glob (e.g. `**/*.{md,ts,tsx}`)
- `Include` — `yes (default)` or `no` (i.e. `includeByDefault: false`)
- `Update` — pre-update shell command (only printed if set)
- `Contexts` — count of configured context entries (not the entries themselves)

This is a YAML-only view. It does NOT show:

- Document counts, embedding state, or last-updated timestamps → use `/qmd:status`
- The `ignore:` glob list → only `qmd collection list` prints those (no slash command for it; type the CLI)
- The actual context strings → use `/qmd:context list`

If the user is debugging "why does this collection behave weirdly," `/qmd:collection-show` is the right call to inspect the update command and the include state. For ignore globs, fall back to `qmd collection list`.

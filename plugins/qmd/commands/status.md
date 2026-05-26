---
description: Show qmd index health, collections, MCP daemon status, and pending embeds
allowed-tools: Bash(qmd status*)
---

Run `qmd status` and report:

- Index size, total documents, vectors, pending embeds
- Collections (name, doc count, last update)
- MCP daemon running state and PID

Flag any actionable issues: pending embeds (suggest `/qmd:embed`), missing context descriptions on collections (suggest `qmd context add`), missing update commands (suggest `qmd collection update-cmd`).

As of qmd 2.5.0, `qmd status` no longer probes the GPU. For device and VRAM, model-cache validity, and embedding fingerprint health, use `/qmd:doctor`.

If `qmd` is not on PATH, tell the user to install it: `npm install -g @tobilu/qmd` or `bun install -g @tobilu/qmd`.

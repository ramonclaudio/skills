---
description: Show qmd index health, collections, MCP daemon status, GPU info, and pending embeds
allowed-tools: Bash(qmd status*)
---

Run `qmd status` and report:

- Index size, total documents, pending embeds
- Collections (name, doc count, last update)
- MCP daemon running state and PID
- GPU detection and VRAM availability

Flag any actionable issues: pending embeds (suggest `/qmd:embed`), missing context descriptions on collections (suggest `qmd context add`), missing update commands (suggest `qmd collection update-cmd`).

If `qmd` is not on PATH, tell the user to install it: `npm install -g @tobilu/qmd` or `bun install -g @tobilu/qmd`.

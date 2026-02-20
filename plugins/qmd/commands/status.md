---
description: Show QMD index status
allowed-tools: Bash(qmd status*)
---

Run `qmd status`. This shows all status output sections:

- Index: path and size on disk
- MCP: running status (checks PID file liveness at ~/.cache/qmd/mcp.pid)
- Documents: total count, embedded count, pending embed count, last update timestamp
- Per-collection: name, pattern, file count, last update, all configured contexts
- Examples: sample commands for ls/get/search
- Models: HuggingFace links for all 3 models (embeddinggemma, qwen3-reranker, qmd-query-expansion)
- Device: GPU info (name, VRAM, offloading status), CPU cores

`qmd --version` shows version with git commit hash when available (e.g., `1.0.8 (abc1234)`).

Status now shows actionable tips when collections lack context descriptions or update commands, with examples of how to set them (e.g., suggested `qmd context add` and `qmd collection update-cmd` invocations).

If `qmd` is not found, tell the user to install it with `npm install -g @tobilu/qmd` or `bun install -g @tobilu/qmd`.

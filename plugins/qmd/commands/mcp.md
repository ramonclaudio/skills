---
description: Start, stop, or check the qmd MCP server (stdio or HTTP daemon)
allowed-tools:
  - Bash(qmd mcp*)
  - Bash(qmd status*)
argument-hint: [stop|--http|--daemon|--port N]
---

Route based on `$ARGUMENTS`:

- (no args) — recommend `/qmd:mcp --daemon` for the background daemon, or note that stdio is launched automatically by Claude Code via `.mcp.json`
- `stop` — `qmd mcp stop` (kills the daemon via PID file at `~/.cache/qmd/mcp.pid`)
- `--http` — `qmd mcp --http` (foreground on port 8181)
- `--daemon` — `qmd mcp --http --daemon` (background, PID file)
- `--port N` — `qmd mcp --http --port N`
- `status` — `qmd status` (shows MCP daemon PID if running)

The plugin's `.mcp.json` already wires up the stdio transport for Claude Code, so most users never need this command. Use `--daemon` only if you want a long-lived shared HTTP server for multiple clients.

Note: the SDK forces `disposeModelsOnInactivity: true`, so an idle daemon will unload models after 5 min and reload them on the next request (~3-8s cold start).

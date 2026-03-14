---
description: Start, stop, or manage the QMD MCP server
allowed-tools:
  - Bash(qmd mcp*)
  - Bash(qmd status*)
argument-hint: [stop|--http|--daemon|--port N]
---

Route based on arguments:
- No args: suggest `qmd mcp --http --daemon` for background daemon, or `qmd mcp` for stdio
- `stop` (positional subcommand): run `qmd mcp stop`. Stops daemon via PID file at ~/.cache/qmd/mcp.pid
- `--http`: run `qmd mcp --http`. HTTP transport on port 8181 (foreground)
- `--daemon`: run `qmd mcp --http --daemon`. Detach as background process
- `--port N`: run `qmd mcp --http --port N`. Custom port
- `status`: run `qmd status`. Shows MCP running status with PID

Transport modes:
- stdio (default): used by .mcp.json plugin config, launched automatically by Claude Code
- HTTP: `POST /mcp` (Streamable HTTP, JSON responses), `GET /health` (liveness with uptime)
- Daemon: background process, PID at ~/.cache/qmd/mcp.pid, logs at ~/.cache/qmd/mcp.log

Daemon mode keeps models loaded in VRAM between queries (~16s → ~10s first query).

After starting daemon, verify with `qmd status`.

If port in use: reports error, try different port or stop existing instance.

# Changelog

## 1.2.0

- Upgrade to `opus` model for skill execution
- Drop `sonnet[1m]` for fix agents, use `sonnet` (1M context unavailable on subscription plans)

## 1.1.0

- Use `sonnet[1m]` (1M context) for skill and fix agents
- Switch discovery agents to `Explore` subagent type (faster, read-only, defaults to haiku)
- Add `Write` to allowed-tools for fix agents
- Replace `TaskOutput` with `TaskGet` in allowed-tools
- Enable model invocation for full agent autonomy

## 1.0.0

- Initial release
- 4-phase sweep: discovery, parallel scan, report, auto-fix
- 3 parallel agents: duplicates/dead code, deps/TODOs/size, naming/consistency
- Severity levels: HIGH, MEDIUM, LOW
- `--dry-run` for report-only mode
- Auto-fix for HIGH severity findings
- Falls back to git-based scoping for large codebases (200+ files)

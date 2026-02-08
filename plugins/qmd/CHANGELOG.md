# Changelog

## 1.2.0

- Upgrade to `opus` model for add skill

## 1.1.0

- Use `sonnet[1m]` (1M context) for add skill
- Add `allowed-tools` to all 7 commands (eliminates permission prompts)
- Add `argument-hint` to commands that take arguments
- Enable model invocation for all skills and commands

## 1.0.0

- Initial release
- Clone GitHub repos to ~/Developer/refs/ and index with QMD
- MCP server with 6 tools: search, vsearch, query, get, multi_get, status
- `/qmd:add` skill for repo onboarding with auto-detection
- Search guide skill (model-invocable background knowledge)
- 7 commands: cleanup, context, list, remove, rename, status, update

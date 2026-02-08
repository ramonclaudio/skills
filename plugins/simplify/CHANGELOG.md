# Changelog

## 1.2.0

- Drop `sonnet[1m]` for worker subagents, use `sonnet` (1M context unavailable on subscription plans)

## 1.1.0

- Use `sonnet[1m]` (1M context) for worker subagents
- Add tool restriction guidance to worker subagent prompts
- Enable model invocation for full agent autonomy

## 1.0.0

- Initial release
- 5-phase workflow: discovery, analysis, work queue, parallel simplification, report
- Up to 5 parallel background agents for file simplification
- Complexity scoring (0-10) with extended thinking
- `--dry-run` for report-only mode
- Skips generated, vendored, and config files

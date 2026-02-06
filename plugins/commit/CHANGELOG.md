# Changelog

## 1.1.0

- Use `sonnet[1m]` (1M context) for skill execution
- Replace GPG detection with `git config --get commit.gpgsign` (matches `Bash(git *)` allowed-tools pattern)
- Fix README: "from main" → "from the current branch"
- Enable model invocation for full agent autonomy

## 1.0.0

- Initial release
- Atomic conventional commits grouped by architectural layer
- Auto-detect GPG signing
- `--analyze` for dry-run analysis
- `--pr` for feature branch + pull request workflow
- `--merge` for PR merge with branch cleanup

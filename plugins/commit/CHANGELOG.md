# Changelog

## 1.4.0

- Add `disable-model-invocation: true` per official docs best practice for side-effect workflows
- Add `version` to `plugin.json` for standalone update detection
- Add explicit `--no-verify` and `--no-gpg-sign` prohibitions to constraints
- Strip `<task>`, `<commit_types>`, `<architectural_layers>`, `<examples>` XML wrappers from skill content
- Flatten examples into fenced code blocks (less noise, same clarity)
- Trim voice section to commit-specific addenda only (global rules handle the rest)
- Fix duplicate `## 1.3.0` changelog entries

## 1.3.0

- Upgrade to `opus` model for skill execution
- Add voice rules referencing global `~/.claude/rules/voice.md`
- Add PR body template with good/bad examples showing correct voice
- Add PR body guidelines: no filler sections, no bold-header lists
- Slim voice section to commit-specific rules (global rules handle the rest)
- Add `activeForm` to TaskCreate calls for commit group spinner UX
- Add `argument-hint` frontmatter for autocomplete preview

## 1.2.0

- Add `--push` flag for direct branch push

## 1.1.0

- Use `sonnet[1m]` (1M context) for skill execution
- Replace GPG detection with `git config --get commit.gpgsign` (matches `Bash(git *)` allowed-tools pattern)
- Fix README: "from main" to "from the current branch"
- Enable model invocation for full agent autonomy

## 1.0.0

- Initial release
- Atomic conventional commits grouped by architectural layer
- Auto-detect GPG signing
- `--analyze` for dry-run analysis
- `--pr` for feature branch + pull request workflow
- `--merge` for PR merge with branch cleanup

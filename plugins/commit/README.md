# Commit Plugin

Atomic commits with conventional format, grouped by architectural layer. GPG signs when available.

## Usage

```bash
/commit:run               # Analyze, commit, verify
/commit:run --analyze     # Analysis only, no commits
/commit:run --pr          # Commit + push + create PR
/commit:run --merge 42    # Merge PR #42 and cleanup
```

## How It Works

### Phase 1 - Analysis

Groups changes by architectural layer (data, backend, UI, config, docs) and commit type. Verifies each group is independently revertable.

### Phase 2 - Execution

Tests GPG availability. If configured, signs with `-S`. If not, commits unsigned. Creates a feature branch when using `--pr` from main.

```
git commit [-S] -m "type(scope): description"
```

### Phase 3 - Verification

Checks each commit for format, atomicity, clarity, and signing. Resets and recommits if verification fails.

### Phase 4 - Pull Request (`--pr`)

Pushes branch and creates PR with summary, changes by layer, and impact sections.

### Phase 5 - Merge (`--merge PR#`)

Merges via `gh pr merge`, checks out main, cleans up local and remote branches.

## Commit Types

| Type | Purpose |
|------|---------|
| feat | New feature |
| fix | Bug fix |
| docs | Documentation |
| refactor | Code reorganization |
| perf | Performance |
| chore | Maintenance |
| test | Tests |
| ci | CI/CD |
| build | Build system |

## GPG Signing

Auto-detected. To enable:

```bash
gpg --full-generate-key
gpg --list-secret-keys --keyid-format=long
git config --global user.signingkey <KEY_ID>
git config --global commit.gpgsign true
```

## Requirements

- `git`
- `gh` (GitHub CLI, for `--pr` and `--merge`)
- `gpg` (optional, for signed commits)

## Version

1.0.0

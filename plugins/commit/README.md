# Commit Plugin

One feature spread across 5 files shouldn't be 5 separate commits, and it shouldn't be one giant commit either. This groups changes by architectural layer so each commit is atomic and revertable.

GPG signs when available.

[Usage](#usage) / [How It Works](#how-it-works) / [Commit Types](#commit-types) / [GPG Signing](#gpg-signing)

## Usage

```bash
/commit               # Analyze, commit, verify
/commit --analyze     # Analysis only, no commits
/commit --push        # Commit + push to current branch
/commit --pr          # Commit + push + create PR
/commit --merge 42    # Merge PR #42 and cleanup
```

<details>
<summary>Fully-qualified syntax</summary>

If another plugin has a conflicting skill name, use the full `plugin:skill` form:

```bash
/commit:commit [--analyze] [--push] [--pr] [--merge PR#]
```

</details>

## How It Works

### Phase 1 - Analysis

Groups changes by architectural layer (data, backend, UI, config, docs) and commit type. Verifies each group is independently revertable.

### Phase 2 - Execution

Tests GPG availability. If configured, signs with `-S`. If not, commits unsigned. Creates a feature branch when using `--pr` from the current branch.

```bash
git commit [-S] -m "type(scope): description"
```

### Phase 3 - Verification

Checks each commit for format, atomicity, clarity, and signing. Resets and recommits if verification fails.

### Phase 3.5 - Push (`--push`)

Pushes commits directly to the current branch. No branch creation, no PR.

### Phase 4 - Pull Request (`--pr`)

Pushes branch and creates PR targeting the base branch with a concise body.

### Phase 5 - Merge (`--merge PR#`)

Merges via `gh pr merge`, checks out the base branch, cleans up local and remote branches.

## Commit Types

| Type | Purpose |
|:---|:---|
| feat | New feature |
| fix | Bug fix |
| docs | Documentation |
| refactor | Code reorganization |
| perf | Performance |
| chore | Maintenance |
| test | Tests |
| ci | CI/CD |
| build | Build system |

<details>
<summary>GPG Signing</summary>

> [!NOTE]
> GPG signing is auto-detected. If `commit.gpgsign` is set in your git config, commits are signed automatically.

To enable:

```bash
gpg --full-generate-key
gpg --list-secret-keys --keyid-format=long
git config --global user.signingkey <KEY_ID>
git config --global commit.gpgsign true
```

</details>

---

> [!IMPORTANT]
> Requires `git` and `gh` (GitHub CLI, for `--pr` and `--merge`). Optional: `gpg` for signed commits.

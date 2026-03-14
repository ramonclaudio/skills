---
name: commit
description: Use this skill when the user asks to commit, push, create a PR, or merge. Atomic conventional commits grouped by architectural layer with GPG signing.
argument-hint: [--analyze] [--push] [--pr] [--merge PR#]
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
  - Read
  - Glob
  - Grep
  - TaskCreate
  - TaskUpdate
  - TaskList
model: opus
---

# Git Workflow - Atomic Commits

ultrathink

<task>
Commit code changes using atomic commits with conventional commit format. Each commit is one independent logical change that can be reverted without breaking other functionality.
</task>

## Voice

Follow `~/.claude/rules/voice.md` for all authored text. Key commit-specific rules:
- Commit messages: lowercase after colon, no period, specific verbs (add, fix, extract, drop)
- PR bodies: start with what changed and why. No filler sections. Test plan at end.
- PR titles: same format as commit messages
- No `**Bold:** description` lists in PR bodies
- Never mention Claude/Anthropic/AI

## Git State (auto-populated)

- **Current branch:** !`git branch --show-current`
- **Status:** !`git status --short`
- **Staged changes:** !`git diff --cached --stat`
- **Unstaged changes:** !`git diff --stat`
- **Full diff:** !`git diff HEAD`
- **Recent commits:** !`git log --oneline -10`

## Arguments

- `$ARGUMENTS` containing `--analyze`: Only run Phase 1 analysis, output groupings without committing
- `$ARGUMENTS` containing `--push`: Run Phases 1-3 on current branch, then push directly (no branch, no PR)
- `$ARGUMENTS` containing `--pr`: Continue through Phase 4 (push and create PR)
- `$ARGUMENTS` containing `--merge`: Run Phase 5 only (merge specified PR and cleanup) - expects PR# as next arg
- No arguments: Run Phases 1-3 (analyze, commit, verify)

## Workflow

### Phase 1 - Analysis

Analyze the git state above. Group changes by layer + type. Verify independence.

Use TaskCreate to track commit groups:
```
TaskCreate(subject: "Commit group N: {files}", description: "type(scope): message | Independent: yes/no", activeForm: "Committing group N: {description}")
```

Output analysis in `<analysis>` tags.

### Phase 2 - Execution

**GPG detection:** Before the first commit, check git config:
```bash
git config --get commit.gpgsign
```
- `true`: Use `git commit -S -m` for all commits
- Empty/unset: Use `git commit -m` (no `-S` flag). Log once: "GPG not configured, commits will not be signed."

**Branch creation (with `--pr` flag):**
```bash
BASE_BRANCH=$(git branch --show-current)
git checkout -b type/description-in-kebab-case
```
Store `BASE_BRANCH` for use in Phase 4. This ensures:
- Commits go to feature branch, not the working branch
- PR targets the correct base branch (not always main)

For each commit group (TaskUpdate status: `in_progress` -> `completed`):
```bash
git add [files]
git commit [-S] -m "type(scope): description"
```

Output in `<commits>` tags.

### Phase 3 - Verification

For each commit, verify:
- Format: `type(scope): lowercase description` (no period)
- Atomic: Single concern, independently revertable
- Clear: Specific about what changed
- Signed: Used `-S` flag (if GPG available)

If verification fails:
```bash
git reset --soft HEAD~1
# Fix and recommit
```

### Phase 3.5 - Push (with `--push`)

Push all commits directly to the current branch. No branch creation, no PR.

```bash
git push
```

If the branch has no upstream, set it:
```bash
git push -u origin HEAD
```

After push, output summary and stop. Do NOT continue to Phase 4.

### Phase 4 - Pull Request (with `--pr`)

Push branch and create PR targeting `BASE_BRANCH` from Phase 2:
```bash
git push -u origin HEAD
gh pr create --base "$BASE_BRANCH" --title "type(scope): description" --body "$(cat <<'EOF'
{1-3 sentences: what changed and why. No headers, no preamble. Start with a verb.}

{Optional: code example or key technical detail if it helps reviewers}

{List of concrete changes, one per line, no bold headers:}
- {what file/module changed and what was done}
- {next change}

## Test plan

- {concrete test performed or command run}
- {next test}
EOF
)"
```

PR body guidelines:
- First line answers "what and why" in plain language
- No "Summary" or "Overview" headers at the top
- No `**Bold:** description` list format
- No "Impact: none" or "Migrations: none" filler. If there's no impact, don't mention it.
- Include breaking changes or migrations only when they exist
- Test plan: list what you actually tested. Commands run, behavior verified.
- Keep it short. Reviewers read diffs, not novels.

### Phase 5 - Merge & Cleanup (with `--merge PR#`)

```bash
BRANCH=$(gh pr view [PR#] --json headRefName -q .headRefName)
BASE=$(gh pr view [PR#] --json baseRefName -q .baseRefName)
gh pr merge [PR#] --merge --delete-branch
git checkout "$BASE"
git pull
git branch -d "$BRANCH"
git fetch --prune
```

Notes:
- Capture branch names before merge (PR metadata disappears after)
- `--merge` preserves all atomic commits (no squashing)
- `--delete-branch` auto-removes remote branch
- Checkout the PR's base branch (not always main)
- `git branch -d` deletes local branch (safe, verifies merged)
- `git fetch --prune` removes stale remote-tracking branches

## Reference

<commit_types>
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
</commit_types>

<architectural_layers>
| Layer | Examples |
|-------|---------|
| Data | schemas, types, migrations, models, database definitions |
| Backend | API routes, server logic, services, controllers, resolvers |
| UI | components, pages, layouts, styles, templates |
| Config | package.json, tsconfig.json, build configs, CI/CD, env |
| Docs | README, CHANGELOG, docs/**, comments, API docs |
</architectural_layers>

<examples>
<example name="multi_layer_feature">
<scenario>Adding subscription feature across 5 architectural layers</scenario>

<analysis>
Group 1 - Data: db/schema.ts | "feat(schema): add subscription and tier tables" | Independent: yes
Group 2 - Backend: api/products-sync.ts, api/customer.ts | "feat(api): add subscription sync endpoints" | Independent: yes
Group 3 - UI: components/pricing-card.tsx | "feat(components): add pricing card component" | Independent: yes
Group 4 - Pages: app/pricing/page.tsx | "feat(pages): add subscription pricing page" | Independent: yes
Group 5 - Docs: README.md, CHANGELOG.md | "docs: document subscription feature setup" | Independent: yes
</analysis>

<commits>
Branch: feat/subscription-pricing
1. git commit -S -m "feat(schema): add subscription and tier tables"
2. git commit -S -m "feat(api): add subscription sync endpoints"
3. git commit -S -m "feat(components): add pricing card component"
4. git commit -S -m "feat(pages): add subscription pricing page"
5. git commit -S -m "docs: document subscription feature setup"
All verified
</commits>
</example>

<example name="single_file_fix">
<scenario>Bug fix in single file</scenario>

<analysis>
Group 1 - Backend: lib/auth-server.ts | "fix(auth): validate session cookie expiration" | Independent: yes
</analysis>

<commits>
Branch: fix/session-expiration
1. git commit -S -m "fix(auth): validate session cookie expiration"
Verified
</commits>
</example>

<example name="verification_failure">
<scenario>Refactoring with vague commit message requiring correction</scenario>

<initial_attempt>
Commit: git commit -S -m "refactor: move product filters"
Verification: FAIL - Too vague, no scope
</initial_attempt>

<correction>
git reset --soft HEAD~1
git commit -S -m "refactor(products): extract filtering logic to shared utils"
Verified
</correction>
</example>
<example name="pr_body_voice">
<scenario>PR body written in the correct voice</scenario>

<good>
Add subscription pricing with Stripe sync and a new pricing page.

Stripe products/prices sync on webhook. Tiers stored in `subscriptions` table with foreign key to users. Pricing card reads from DB, not hardcoded.

- schema: add `subscriptions` and `tiers` tables
- api: webhook handler for `product.updated` and `price.updated`
- api: customer portal session endpoint
- components: pricing card with tier comparison
- pages: `/pricing` with tier toggle (monthly/annual)

## Test plan

- Triggered `stripe trigger product.updated`, verified DB write
- Loaded `/pricing`, confirmed tiers render from DB
- Toggled monthly/annual, verified price switch
- `bun test` passes
</good>

<bad>
## Summary

This PR introduces a comprehensive subscription pricing system with Stripe integration. The changes span multiple architectural layers, ensuring a robust and scalable implementation.

## Changes

- **Schema:** Added subscription and tier tables to support the new pricing model
- **API:** Implemented webhook handlers for Stripe product and price synchronization
- **Components:** Created a new pricing card component showcasing tier comparisons
- **Pages:** Added a dedicated pricing page with intuitive monthly/annual toggle

## Impact

- **Performance:** None
- **Breaking:** None
- **Migrations:** New tables added

## Additional Notes

This implementation leverages Stripe's webhook system to ensure real-time synchronization of pricing data, providing a seamless experience for end users.
</bad>
</example>
</examples>

## Recovery

**Important:** Claude Code's `/rewind` and `Esc+Esc` do NOT undo git operations (bash commands aren't tracked by checkpoints).

| Situation | Recovery |
|-----------|----------|
| Bad commit message | `git reset --soft HEAD~1` then recommit |
| Wrong files committed | `git reset --soft HEAD~1` then re-stage |
| Multiple bad commits | `git reset --soft HEAD~N` (N = number of commits) |
| Already pushed | `git revert <hash>` (creates new commit) |
| Need to find old state | `git reflog` then `git reset --hard <hash>` |

## Constraints

- Execute actual bash commands (not suggestions)
- Use Bash tool for all git operations
- Stop and report errors immediately
- Group by layer: data -> backend -> UI -> config -> docs
- Commit in dependency order
- Verify independently revertable
- Sign commits with `-S` flag when GPG is available
- Be terse in confirmations
- Never mention Claude, Claude Code, Anthropic, or AI in commits, PR bodies, or any output
- Never use co-authored-by or "generated by" attributions
- All text must pass as human-written. Re-read before submitting. If it sounds like a chatbot wrote it, rewrite it.

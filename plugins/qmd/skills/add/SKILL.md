---
name: add
description: Clone a GitHub repo to ~/Developer/refs/, auto-detect file types, index with QMD, embed for search.
argument-hint: <url-or-owner/repo> [--name N] [--mask P] [--full] [--defer-embed] [--dry-run]
disable-model-invocation: true
context: fork
allowed-tools:
  - Bash(qmd *)
  - Bash(git *)
  - Bash(mkdir *)
  - Bash(ls *)
  - Bash(trash *)
  - Read
  - Edit
model: sonnet
---

# QMD Add — Clone + Index a GitHub Repo

## Current State
!`qmd status 2>/dev/null || echo "No QMD index yet"`

## Current Config
!`cat ~/.config/qmd/index.yml 2>/dev/null || echo "No config yet"`

## Conventions

- Refs directory: `~/Developer/refs/` — all steps below reference this as `REFS`
- QMD config: `~/.config/qmd/index.yml`
- Never delete anything — use `trash`, never `rm`
- Execute commands, not suggestions
- If any step fails, stop and diagnose. Do not continue with broken state.

---

## Step 1: Parse input

- Full URL: `https://github.com/owner/repo` → name = `repo`
- Shorthand: `owner/repo` → URL = `https://github.com/owner/repo`, name = `repo`
- `--name` overrides (must be `[a-zA-Z0-9_-]` only)
- `--full`: clone with complete history (default is shallow `--depth 1`)
- `--defer-embed`: skip embedding, run `/qmd:update` later to embed in batch
- `--mask`: skip auto-detection, use provided glob pattern
- `--dry-run`: run Steps 1-3 only, print execution plan, exit without side effects

## Step 2: Clone or pull

```bash
mkdir -p ~/Developer/refs
```

If `REFS/<name>` already exists:
```bash
git -C ~/Developer/refs/<name> pull --ff-only
```

If pull fails with `fatal: Not possible to fast-forward`:
- Report: "Branch diverged from remote. Re-run with manual resolution or run `git -C ~/Developer/refs/<name> pull --rebase`."
- Stop. Do not continue.

Otherwise, shallow clone (default):
```bash
git clone --depth 1 https://github.com/<owner>/<repo> ~/Developer/refs/<name>
```

If `--full`: omit `--depth 1`.

## Step 3: Detect mask

If `--mask` provided, use it and skip to Step 4.

Detect from the repo root:

```
detected = []

if package.json exists OR any .ts/.tsx files:
    detected += "typescript"
if Cargo.toml exists OR any .rs files:
    detected += "rust"
if go.mod exists OR any .go files:
    detected += "go"
if pyproject.toml exists OR any .py files:
    detected += "python"
if Package.swift exists OR any .swift files:
    detected += "swift"

if len(detected) == 0:
    STOP → "Could not detect project type. Re-run with --mask '<glob>'."
if len(detected) > 1:
    WARN → "Multiple types detected: {detected}. Merging masks."
    mask = union of all matched type extensions
if len(detected) == 1:
    mask = extensions for the single matched type
```

Extension table (for building `**/*.{...}` mask):

| Type | Extensions |
|------|------------|
| typescript | `md,mdx,txt,ts,tsx,js,jsx,json,yaml,yml,css` |
| rust | `md,txt,rs,toml,yaml,yml` |
| go | `md,txt,go,mod,yaml,yml` |
| python | `md,txt,py,toml,yaml,yml,cfg` |
| swift | `md,txt,swift,yaml,yml` |

Print detected type(s) and final mask before proceeding.

### Dry-run gate

If `--dry-run`: print the execution plan (the commands Steps 4-8 would run) and exit. Do not clone, add collections, edit config, or embed.

## Step 4: Add collection

```bash
qmd collection add ~/Developer/refs/<name> --name <name> --mask "<mask>"
```

If collection already exists (command errors), remove first then re-add:
```bash
qmd collection remove <name>
qmd collection add ~/Developer/refs/<name> --name <name> --mask "<mask>"
```

## Step 5: Set auto-pull

Try the CLI first:
```bash
qmd collection set <name> update "git pull --ff-only"
```

If `qmd collection set` is not a valid command, fall back to direct config edit:
- Read `~/.config/qmd/index.yml`
- Add `update: "git pull --ff-only"` under the collection entry
- Re-read to confirm the key exists

> **Known coupling:** Direct config editing breaks if qmd changes its YAML schema. Prefer CLI when available.

## Step 6: Add context

Read the repo's `README.md`. Extract the first non-empty paragraph after the H1 heading (skip badges, blank lines, shields.io links). Truncate to one sentence.

```bash
qmd context add qmd://<name> "<one-sentence description>"
```

## Step 7: Embed

If `--defer-embed`: skip. Print: "Embedding deferred. Run `/qmd:update` to embed."

Otherwise:
```bash
qmd embed
```

First run downloads models (~2GB). If interrupted, retry.

## Step 8: Verify

```bash
qmd status
```

Confirm: non-zero document count for the new collection. If embed was not deferred, confirm zero pending embeddings.

If embed ran, run a sample search to verify the mask indexed useful content:
```bash
qmd search "<keyword from README>" --collection <name> --limit 3
```

Zero results after successful embedding means the mask missed the important files. Re-run with `--mask` to fix.

Report: collection name, document count, mask used, clone type (shallow/full).

## Recovery

This skill is idempotent. If it fails partway through, re-run `/qmd:add` with the same arguments — Step 2 pulls instead of re-cloning, Step 4 removes and re-adds the collection.

---

## Reference

- For usage examples, see [examples.md](examples.md)

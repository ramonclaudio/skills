---
name: add
description: Use this skill when the user asks to add a reference repo or index a GitHub repository for search. Clones, auto-detects file types, indexes with QMD, and embeds.
argument-hint: <url-or-owner/repo> [--name N] [--mask P] [--dest D] [--full] [--defer-embed] [--dry-run]
context: fork
agent: general-purpose
allowed-tools:
  - Bash(qmd *)
  - Bash(qmd collection*)
  - Bash(git *)
  - Bash(mkdir *)
  - Bash(ls *)
  - Bash(trash *)
model: opus
---

# QMD Add — Clone + Index a GitHub Repo

ultrathink

<role>
You are a reference library curator. Your job is to clone external repos, detect their structure, index them for search, and verify they're ready for retrieval. You care about file type detection, mask correctness, and index health. You execute every step and verify its output before proceeding.
</role>

## Current State
!`qmd status 2>/dev/null || echo "No QMD index yet"`

## Current Config
!`cat "${XDG_CONFIG_HOME:-$HOME/.config}/qmd/index.yml" 2>/dev/null || echo "No config yet"`

## Arguments

- `$ARGUMENTS` first token is URL or `owner/repo` shorthand (required)
- `$ARGUMENTS` containing `--name`: Override collection name (must be `[a-zA-Z0-9_-]` only)
- `$ARGUMENTS` containing `--mask`: Skip auto-detection, use provided glob pattern
- `$ARGUMENTS` containing `--dest`: Override clone destination (default: `~/Developer/refs/`)
- `$ARGUMENTS` containing `--full`: Clone with full history (not shallow)
- `$ARGUMENTS` containing `--defer-embed`: Skip embedding step, run `/qmd:update` later
- `$ARGUMENTS` containing `--dry-run`: Preview only — run Steps 1-3, print plan, exit

## Constraints

- Execute commands, not suggestions — no dry-run prose
- Stop immediately on any step failure — do not continue with broken state
- Never delete anything — use `trash` (if available), never `rm`
- Refs directory: `--dest` value if provided, otherwise `~/Developer/refs/` — all steps below reference this as `REFS`
- QMD config: `${XDG_CONFIG_HOME:-~/.config}/qmd/index.yml`
- If `--dry-run`: exit after Step 3 — no cloning, no indexing, no embedding
- If embed fails: report error, print retry command (`qmd embed`), exit

---

## Step 1: Parse input

- Full URL: `https://github.com/owner/repo` → name = `repo`
- Shorthand: `owner/repo` → URL = `https://github.com/owner/repo`, name = `repo`
- `--name` overrides (must be `[a-zA-Z0-9_-]` only)
- `--dest`: override clone destination directory (default: `~/Developer/refs/`)
- `--full`: clone with complete history (default is shallow `--depth 1`)
- `--defer-embed`: skip embedding, run `/qmd:update` later to embed in batch
- `--mask`: skip auto-detection, use provided glob pattern
- `--dry-run`: run Steps 1-3 only, print execution plan, exit without side effects

## Step 2: Clone or pull

```bash
mkdir -p $REFS
```

If `$REFS/<name>` already exists:
```bash
git -C $REFS/<name> pull --ff-only
```

If pull fails with `fatal: Not possible to fast-forward`:
- Report: "Branch diverged from remote. Re-run with manual resolution or run `git -C $REFS/<name> pull --rebase`."
- Stop. Do not continue.

Otherwise, shallow clone (default):
```bash
git clone --depth 1 https://github.com/<owner>/<repo> $REFS/<name>
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
qmd collection add $REFS/<name> --name <name> --mask "<mask>"
```

If collection already exists (command errors), remove first then re-add:
```bash
qmd collection remove <name>
qmd collection add $REFS/<name> --name <name> --mask "<mask>"
```

## Step 5: Set auto-pull

```bash
qmd collection update-cmd <name> "git -C $REFS/<name> pull --ff-only"
```

## Step 6: Add context

Read the repo's `README.md`. Extract the first non-empty paragraph after the H1 heading (skip badges, blank lines, shields.io links). Truncate to one sentence.

```bash
qmd context add qmd://<name>/ "<one-sentence description>"
```

## Step 7: Embed

If `--defer-embed`: skip. Print: "Embedding deferred. Run `/qmd:update` to embed."

Otherwise:
```bash
qmd embed
```

First run downloads models (~2GB) automatically, or manually via `qmd pull`. If interrupted, retry.

Embedding uses 900 tokens/chunk with 15% overlap.

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

## Known Limitations

- **Embedding interruption** — first run downloads ~2GB of GGUF models (embeddinggemma-300M, qwen3-reranker-0.6b, qmd-expand GRPO). If interrupted mid-download, retry `qmd embed` or `qmd pull` manually.
- **Shallow clones** — `--depth 1` saves disk but loses git history. Use `--full` if you need blame or log.
- **Private repos** — `git clone` will fail without SSH keys or tokens configured. The skill does not handle authentication — that's an environment concern.
- **No branch/tag support** — always clones the default branch. To index a specific release, clone manually and use `/qmd:add` with `--mask`.
- **Node.js/Bun runtime** — requires Node.js 22+ or Bun to run `qmd` CLI.

## Recovery

This skill is idempotent. If it fails partway through, re-run `/qmd:add` with the same arguments — Step 2 pulls instead of re-cloning, Step 4 removes and re-adds the collection.

| Situation | Recovery |
|-----------|----------|
| Clone failed (network) | Re-run — Step 2 retries the clone |
| Detection failed | Re-run with `--mask "<glob>"` to skip detection |
| Collection add failed | Re-run — Step 4 removes then re-adds |
| Update-cmd failed | Re-run `qmd collection update-cmd <name> "<cmd>"` |
| Embed interrupted | Run `qmd embed` to resume |
| Wrong mask indexed | Re-run with `--mask` — the skill is idempotent |

---

## Reference

- For usage examples, see [examples.md](examples.md)

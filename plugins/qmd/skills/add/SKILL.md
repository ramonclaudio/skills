---
name: add
description: Adds a reference collection to qmd. Accepts a GitHub URL, owner/repo shorthand, or a local directory path. Auto-detects file types, sets ignore globs, indexes with AST chunking, embeds, and verifies. Use when adding a new reference codebase or local notes folder for search.
argument-hint: <url|owner/repo|local-path> [--name N] [--mask P] [--dest D] [--full] [--defer-embed] [--dry-run]
context: fork
agent: general-purpose
allowed-tools:
  - Bash(qmd *)
  - Bash(git *)
  - Bash(mkdir *)
  - Bash(ls *)
  - Bash(test *)
  - Bash(realpath *)
  - Bash(trash *)
  - Read
  - Edit
model: opus
---

# QMD Add: Clone or Index a Reference Collection

ultrathink

<role>
You are a reference library curator. Your job is to add new collections to qmd: cloning external GitHub repos OR registering existing local directories, detecting their structure, setting ignore globs, indexing them for search, embedding, and verifying they're ready for retrieval. You care about file type detection, mask correctness, ignore patterns, and index health. You execute every step and verify its output before proceeding.
</role>

## Current Collections
!`qmd collection list 2>/dev/null || echo "No collections yet"`

## Arguments

- `$ARGUMENTS` first token is required and is one of:
  - **GitHub URL**: `https://github.com/owner/repo` (or `git@github.com:owner/repo.git`)
  - **Owner/repo shorthand**: `owner/repo` (e.g. `vercel/next.js`)
  - **Local directory**: any absolute path (`/path/...`), home-relative (`~/path/...`), or `.`/`./path` for cwd-relative. Detected when `test -d` succeeds OR when the token starts with `/`, `~/`, `./`, or `../`.
- `$ARGUMENTS` containing `--name`: Override collection name (must match `[a-zA-Z0-9_-]+`)
- `$ARGUMENTS` containing `--mask`: Skip auto-detection, use provided glob pattern
- `$ARGUMENTS` containing `--dest`: Override clone destination (default: `~/Developer/refs/`). **GitHub paths only**, ignored for local paths.
- `$ARGUMENTS` containing `--full`: Clone with full history (not shallow). **GitHub paths only**.
- `$ARGUMENTS` containing `--defer-embed`: Skip embedding step, run `/qmd:update` later
- `$ARGUMENTS` containing `--dry-run`: Preview only. Run Steps 1-3, print plan, exit

## Constraints

- Execute commands, not suggestions. No dry-run prose
- Stop immediately on any step failure. Do not continue with broken state
- Never delete anything. Use `trash` (if available), never `rm`
- For GitHub paths: refs directory is `--dest` if provided, otherwise `~/Developer/refs/`. Steps reference this as `REFS`. Final collection path is `$REFS/<name>`.
- For local paths: the user's directory is the collection path verbatim (after resolving `~`/`.`). `REFS` and `--dest` are not used.
- QMD config: `${XDG_CONFIG_HOME:-~/.config}/qmd/index.yml`
- If `--dry-run`: exit after Step 3. No cloning, no indexing, no embedding
- If embed fails: report error, print retry command (`qmd embed`), exit

---

## Step 1: Parse input and detect mode

Look at the first token of `$ARGUMENTS`:

1. **GitHub URL** (`https://github.com/...` or `git@github.com:...`):
   - Mode = `github`
   - Parse `<owner>/<repo>`
   - Default name = `<repo>` (override with `--name`)
   - Collection path = `$REFS/<name>`

2. **Owner/repo shorthand** (matches `^[\w.-]+/[\w.-]+$` AND is not an existing directory):
   - Mode = `github`
   - URL = `https://github.com/<owner>/<repo>`
   - Default name = `<repo>` (override with `--name`)
   - Collection path = `$REFS/<name>`

3. **Local directory** (token starts with `/`, `~/`, `./`, `../`, OR `test -d <token>` succeeds):
   - Mode = `local`
   - Resolve the path: `realpath <token>` (or shell expansion for `~`)
   - Verify the directory exists. If not, STOP: "Local path does not exist: <path>".
   - Default name = the basename of the resolved path, lowercased and `handelize`'d (`[a-zA-Z0-9_-]+`)
   - Collection path = the resolved local path verbatim
   - **Ignore** `--dest` and `--full` if provided (warn the user they don't apply to local mode)

`--name`, `--mask`, `--defer-embed`, `--dry-run` apply in both modes.

Print the parsed mode + name + final collection path before proceeding so the user can confirm.

## Step 2: Clone, pull, or skip

**If mode = `github`:**

```bash
mkdir -p $REFS
```

If `$REFS/<name>` already exists, refresh it to the remote tip. A shallow fetch + reset keeps the read-only mirror shallow and never hits a fast-forward failure:
```bash
git -C $REFS/<name> fetch --depth 1 origin HEAD && git -C $REFS/<name> reset --hard FETCH_HEAD
```

Otherwise, shallow clone (default):
```bash
git clone --depth 1 https://github.com/<owner>/<repo> $REFS/<name>
```

If `--full`: omit `--depth 1`.

**If mode = `local`:**

Skip cloning entirely. The directory already exists (verified in Step 1). Move directly to Step 3.

If the local directory is a git repo, that's fine — Step 5 still sets a `git pull --ff-only` update command so `/qmd:update` will refresh it. If it's not a git repo (e.g., `~/Documents/notes`), Step 5 should leave the update command empty so `/qmd:update` just re-indexes without trying to pull.

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

Use the resolved collection path from Step 1 (called `<path>` here — `$REFS/<name>` for github mode, the user's directory for local mode):

```bash
qmd collection add <path> --name <name> --mask "<mask>"
```

If collection already exists (command errors), remove first then re-add:
```bash
qmd collection remove <name>
qmd collection add <path> --name <name> --mask "<mask>"
```

## Step 5: Set auto-pull (github mode) and ignore patterns

**If mode = `github`:** configure the pre-update command. Use a shallow fetch + reset so the read-only mirror stays shallow and never hits a fast-forward failure:

```bash
qmd collection update-cmd <name> "git -C $REFS/<name> fetch --depth 1 origin HEAD && git -C $REFS/<name> reset --hard FETCH_HEAD"
```

**If mode = `local`:** check whether the directory is a git repo:

```bash
test -d <path>/.git && echo "git" || echo "not-git"
```

- If it's a git repo, set a non-destructive pull (never `reset --hard` a directory the user might be editing): `qmd collection update-cmd <name> "git -C <path> pull --ff-only"`. If it can't fast-forward, `/qmd:update` surfaces the error and the user resolves it, which is safer than discarding their work.
- If it's not a git repo (e.g. notes folder), leave the update command unset. `/qmd:update` will still re-index it on each run (file mtime detection picks up changes).

Then write `ignore:` globs into the YAML for the collection. The CLI has no subcommand to set ignore patterns — edit `${XDG_CONFIG_HOME:-~/.config}/qmd/index.yml` directly:

```yaml
collections:
  <name>:
    # ... existing fields ...
    ignore:
      - "out/**"
      - "target/**"
      - "Pods/**"
      - "**/*.test.*"
      - "**/*.spec.*"
      - "**/__tests__/**"
      - "**/__snapshots__/**"
      - "**/fixtures/**"
```

**What qmd already excludes by default (do NOT add these):**

qmd hardcodes a builtin exclude list of `node_modules`, `.git`, `.cache`, `vendor`, `dist`, `build` (verified in `src/cli/qmd.ts:1504` and `src/store.ts:1183`) AND filters out every path that contains a component starting with `.` (the dotfile filter at `src/cli/qmd.ts:1529`). So all of these are already excluded automatically without you doing anything:

- `node_modules`, `dist`, `build`, `vendor`, `.git`, `.cache` (hardcoded list)
- `.next`, `.nuxt`, `.venv`, `.build`, `.vscode`, `.github`, `__pycache__`-style hidden dirs (dotfile filter)

Only specify ignore patterns for things qmd doesn't already handle:

- **Generated outputs** that aren't in the hardcoded list: `out/**` (Next.js export), `target/**` (Rust), `bin/**`/`obj/**` (.NET)
- **Package manager dirs** that aren't dotfiles: `Pods/**` (CocoaPods), `Carthage/**`
- **Test/snapshot patterns**: `**/*.test.*`, `**/*.spec.*`, `**/__tests__/**`, `**/__snapshots__/**`
- **Fixture/example dumps**: `**/fixtures/**`, `**/__fixtures__/**`

Adjust to language. For Python repos add `*.egg-info/**`. For Rust just `target/**`. For Swift add `Pods/**`, `Carthage/**`. The `ignore:` field was added in upstream qmd 1.1.2. Without it, large monorepos waste embedding budget on test fixtures, build outputs, and snapshots.

## Step 6: Add context

The collection's root context is what the MCP server injects with every search hit, so it matters for relevance. Compose a one-sentence description.

**If mode = `github`** OR a `README.md` exists at the collection root: read it, find the first non-empty paragraph after the H1 (skip badges, blank lines, shields.io links), and truncate to one sentence.

**If mode = `local` and no README**: ask the user for a one-sentence description. Don't invent one. Don't proceed with a placeholder.

```bash
qmd context add qmd://<name>/ "<one-sentence description>"
```

## Step 7: Embed

If `--defer-embed`: skip. Print: "Embedding deferred. Run `/qmd:update` to embed."

Otherwise, embed with AST-aware chunking for code files:

```bash
qmd embed --chunk-strategy auto
```

`--chunk-strategy auto` (added in upstream 2.1.0) uses tree-sitter to chunk `.ts/.tsx/.js/.jsx/.mts/.cts/.mjs/.cjs/.py/.go/.rs` files at function, class, and import boundaries instead of arbitrary text positions. Markdown and unknown file types stay on regex chunking. This is the right default for code repos. If grammars aren't installed it falls back to regex automatically.

First run downloads models (~2GB) automatically, or manually via `qmd pull`. If interrupted, retry.

Markdown chunks use 900 tokens with 15% overlap. AST chunks land on natural code boundaries.

## Step 8: Verify

```bash
qmd status
```

Confirm: non-zero document count for the new collection. If embed was not deferred, confirm zero pending embeddings.

If embed ran, run a sample search to verify the mask indexed useful content:
```bash
qmd search "<keyword from README>" -c <name> -n 3
```

Zero results after successful embedding means the mask missed the important files. Re-run with `--mask` to fix.

Report: mode (github/local), collection name, collection path, document count, mask used, ignore patterns set, chunk strategy, and (github mode only) clone type (shallow/full).

## Known Limitations

- First run downloads ~2GB of GGUF models (embeddinggemma-300M, qwen3-reranker-0.6b, qmd-expand GRPO). If interrupted mid-download, retry `qmd embed` or `qmd pull` manually.
- **github mode**: `--depth 1` (default) saves disk but loses git history. Use `--full` if you need blame or log.
- **github mode**: `git clone` will fail without SSH keys or tokens configured. The skill does not handle authentication, that's an environment concern.
- **github mode**: always clones the default branch. To index a specific release, clone manually then re-run `/qmd:add` against the local path.
- **local mode**: `--dest` and `--full` are ignored.
- **local mode**: if the directory is not a git repo, `/qmd:update` will only re-index (no pull). Re-run `/qmd:add <path>` if you move the directory.
- Requires Node.js 22+ or Bun to run `qmd` CLI.
- Type detection covers TypeScript, Rust, Go, Python, Swift. Java, Kotlin, C/C++, C#, Ruby, Elixir, Haskell, Zig, Nim, OCaml are not auto-detected. Pass `--mask` explicitly for those.
- AST chunking via `--chunk-strategy auto` only covers `.ts/.tsx/.js/.jsx/.mts/.cts/.mjs/.cjs/.py/.go/.rs`. Swift, Java, Kotlin, C/C++, C#, Ruby, and other languages fall back to regex chunking even with `--chunk-strategy auto`.

## Recovery

This skill is idempotent. If it fails partway through, re-run `/qmd:add` with the same arguments. Step 2 pulls instead of re-cloning, Step 4 removes and re-adds the collection.

| Situation | Recovery |
|-----------|----------|
| Clone failed (network) | Re-run. Step 2 retries the clone |
| Local path not found | Verify the path exists and is a directory; pass an absolute path |
| Detection failed | Re-run with `--mask "<glob>"` to skip detection |
| Collection add failed | Re-run. Step 4 removes then re-adds |
| Update-cmd failed | Re-run `/qmd:collection-update-cmd <name> "<cmd>"` |
| Embed interrupted | Run `/qmd:embed` to resume |
| Wrong mask indexed | Re-run with `--mask`. The skill is idempotent |

---

## Gotchas

- Collections must be re-indexed after upstream docs change (`/qmd:update`).
- Embeddings must be regenerated after model updates (`/qmd:embed`).
- `--mask` glob must match actual file extensions. Wrong mask = empty collection.
- Large repos (>1000 files) take several minutes to embed. Use `--defer-embed` and run `/qmd:embed` separately.

---

## Reference

- For usage examples, see [examples.md](examples.md)

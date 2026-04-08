# Changelog

The plugin and the qmd CLI tool have independent version trees. Plugin versions are noted as `1.x` here. Upstream qmd CLI versions are referenced inline (e.g. "qmd CLI 2.1.0").

## 1.8.0

Refocus the plugin as a tight Claude Code skill for using qmd CLI 2.1.0, not a documentation port of upstream qmd. Cleanup, restoration, and exhaustive cross-reference against `tobi/qmd@c2f3a40`.

The 1.7.0 plugin had drifted into shipping ~1,800 lines of duplicated upstream qmd reference docs at the plugin root that no SKILL referenced (so Claude never loaded them), plus 22 slash commands that were mostly 1:1 bash wrappers around `qmd <subcommand>` with no Claude-readable output story. This release deletes the dead weight, keeps and improves the operations that have real Claude value, and verifies every claim against the actual qmd source.

### Removed (dead weight, ~1,800 lines)

- `references/architecture.md` (551 lines) — duplicated upstream qmd internals docs, never referenced by any SKILL
- `references/cli-reference.md` (590 lines) — duplicated `qmd --help` output
- `references/models.md` (278 lines) — duplicated upstream model docs
- `references/MCP-SETUP.md` (267 lines) — `.mcp.json` already wires up the server
- 5 slash commands with no Claude story: `/qmd:collection-list`, `/qmd:list`, `/qmd:multi-get`, `/qmd:vsearch`, `/qmd:collection-add` (replaced by `/qmd:add` now accepting local paths)

### Rewritten

- **`skills/search/SKILL.md`** — cut from 376 lines to 153. Removed everything the upstream MCP server already injects via tool descriptions and dynamic instructions (grammar, lex syntax, query type tables, "always provide intent" reminder, basic examples). Kept only what Claude can't get from upstream: when to use qmd vs `Grep`/`Glob`, the MCP-skips-expansion fact, subagent hygiene, recovery patterns, score interpretation, named indexes, the `@<absolute-path>` Claude Code shortcut, CLI fallback workflow, and stack-specific intent examples (Convex, Expo, Next.js).
- **`skills/search/references/examples.md`** (new) — 9 worked query examples moved out of SKILL.md per the official "keep SKILL.md under 500 lines, move detailed reference to separate files" guidance.
- **`skills/add/SKILL.md`** — front-loaded the description, then extended to handle local directory paths in addition to GitHub URLs. The skill now detects three input modes: GitHub URL, `owner/repo` shorthand, OR a local directory path (`/abs`, `~/...`, `./...`, or any token where `test -d` succeeds). For local mode, the clone step is skipped, the resolved path becomes the collection root, `--dest`/`--full` are ignored, and Step 5 only sets a `git pull` update command if the directory is actually a git repo. Step 6 prompts the user for a context description if there's no `README.md`. Recovery table updated for both modes.
- **All 11 retained commands** — frontmatter audited, descriptions front-loaded, bodies cut to 5-25 lines each. Each command body now says what to run, what to report, and any gotchas — not what `qmd --help` already says.
- **`README.md`** — rewritten to describe the plugin as a Claude skill, not a qmd documentation mirror. Dropped the SDK section, the env vars table, the GGUF model details, the MCP HTTP transport docs, and the giant CLI Extras list. Added a clear "what's in the plugin" tree and a "why slash commands AND an MCP server" section explaining the architecture.
- **`plugin.json` + `marketplace.json`** — description rewritten to say what the plugin actually does. Added `homepage`, expanded keywords. Note: the qmd CLI tool stays on its own version track (`2.1.0`); this plugin tracks its own `1.x` line.

### Added / restored

The cleanup initially over-rotated and dropped 10 capabilities that had real Claude value. They're all back now:

- **`/qmd:add` local-path mode** (covered above)
- **Score interpretation table** in `skills/search/SKILL.md` mapping 0.8+/0.5-0.8/0.2-0.5/0-0.2 to relevance and action
- **`minScore` calibration**: explains why `minScore: 0.5` is too aggressive for broad queries, recommends `0` for exploratory and `0.3` as a sane junk floor
- **Named indexes** section in search SKILL documenting `--index <name>` with the path resolution rules (`<name>.sqlite` + `<name>.yml`), and noting that the plugin's MCP server uses the default index so named indexes are CLI-only
- **`@<absolute-path>` shortcut** in the Retrieval section: tells Claude how to attach a search hit's full file as a Claude Code attachment without going through `get`
- **`/qmd:context`** command for managing collection contexts (list/add/rm) with full path-format reference (`qmd://`, `/`, relative, absolute)
- **`/qmd:rename`** command for renaming collections (5-step rename across YAML, document records, and virtual paths)
- **`/qmd:collection-update-cmd`** for setting/changing the pre-update shell command on existing collections
- **`/qmd:collection-include` + `/qmd:collection-exclude`** for toggling `includeByDefault` on noisy or session-scoped collections
- **`/qmd:collection-show`** for inspecting a single collection's YAML config (path, pattern, include state, update command, context count)
- **`qmd ls` browse capability** documented in the search SKILL CLI fallback section (the only way to discover files in a collection without searching, useful for verifying an `/qmd:add` mask after the fact)
- **`templates/index.yml`** — moved from `references/example-index.yml`. Stays as a template for users setting up qmd manually.
- **`skills/search/SKILL.md` `allowed-tools`** — explicitly lists `mcp__qmd__query`, `mcp__qmd__get`, `mcp__qmd__multi_get`, `mcp__qmd__status` so Claude can call them without per-use permission prompts when the search SKILL is active

### Sync with qmd CLI 2.1.0

Backfilled coverage of features added in upstream 2.1.0 that were missing or stale in the prior plugin:

- **`--intent`** flag and MCP `intent` parameter for query disambiguation. Reframed as "treat as required" in the search SKILL because the upstream MCP server's standing instruction is "Always provide `intent` on every search call to disambiguate and improve snippets."
- **`--no-rerank`** flag and MCP `rerank: false` for fast results on CPU-only machines
- **`-C` / `--candidate-limit`** flag and MCP `candidateLimit` for tuning how many candidates reach the reranker
- **`--explain`** flag for emitting RRF + reranker score traces
- **`--chunk-strategy auto|regex`** on `embed` and `query` for AST-aware chunking via tree-sitter (`.ts/.tsx/.js/.jsx/.mts/.cts/.mjs/.cjs/.py/.go/.rs`)
- **`--max-docs-per-batch`** and **`--max-batch-mb`** embed batch tuning
- **`/qmd:bench`** new slash command for `qmd bench <fixture.json>` search quality benchmarks (4 backends: bm25, vector, hybrid, full)
- **YAML config**: per-collection `ignore: ["pattern", ...]`, top-level `models: { embed, rerank, generate }` block, top-level `editor_uri`/`editor_uri_template` for clickable OSC 8 terminal links
- **Env vars**: `QMD_EMBED_MODEL`, `QMD_RERANK_MODEL`, `QMD_GENERATE_MODEL`, `QMD_EMBED_CONTEXT_SIZE`, `QMD_RERANK_CONTEXT_SIZE`, `QMD_EXPAND_CONTEXT_SIZE`, `QMD_LLAMA_GPU`, `QMD_EDITOR_URI` documented in templates/index.yml and pipeline.md

### Fixed

Factual errors and stale claims caught by reading the upstream source line by line:

- **Reranker context**: was documented as 2048 tokens (the pre-2.1.0 default), actually 4096 since upstream 2.1.0 (configurable via `QMD_RERANK_CONTEXT_SIZE`). Verified at `src/llm.ts:794-797`.
- **Reranker template overhead**: was 200 tokens, actually 512 since upstream 2.1.0. Verified at `src/llm.ts:1145`.
- **Reranker API**: pipeline reference said `rankAll()`. Source uses `rankAndSort()` (`src/store.ts`).
- **Embed batch defaults**: docs claimed "batches of 32" (a stale magic number). Actual defaults are 64 docs / 64 MB, whichever limit is hit first (`DEFAULT_EMBED_MAX_DOCS_PER_BATCH = 64`, `DEFAULT_EMBED_MAX_BATCH_BYTES = 64 * 1024 * 1024` in `src/store.ts:47-48`).
- **GPU detection**: claimed manual `CUDA > Metal > Vulkan` priority. Upstream 1.1.2 deleted ~220 lines of manual fallback code in favor of node-llama-cpp's `build: "autoAttempt"`. Override with `QMD_LLAMA_GPU`.
- **MCP path skips expansion**: when the MCP `query` tool is called (or CLI typed query documents), qmd uses `structuredSearch` which **skips the local LLM query expansion entirely**. Only `qmd query "plain text"` runs the expansion model. This means typed sub-query quality matters more from MCP — Claude is the expansion model. Documented in pipeline.md, search SKILL, and commands/query.md.
- **Model lifecycle CLI vs MCP**: CLI keeps models loaded across `qmd` invocations within the 5-min idle window (`disposeModelsOnInactivity: false`). The SDK `createStore()` and therefore the MCP server force `disposeModelsOnInactivity: true`, so an idle MCP daemon will fully unload models from VRAM and pay a ~3-8s cold start on the next request. Verified at `src/index.ts:367` vs `src/cli/qmd.ts:114-130`.
- **MCP `get` and `multi_get` return `resource` content blocks**, not plain text. Claude Code surfaces these as document attachments with `qmd://` URIs and `text/markdown` mime type. Documented in MCP-SETUP.md (now removed) and the search SKILL Retrieval section.
- **MCP REST endpoint quirk**: `POST /query` (alias `/search`) silently ignores `candidateLimit`, `rerank`, and `chunkStrategy` — only reads `searches`, `collections`, `limit`, `minScore`, `intent`. Verified at `src/mcp/server.ts:651-700`. Documented in commands/mcp.md.
- **Collection name validation on rename**: docs claimed `collection rename` errors on invalid names. `collectionRename()` (`src/cli/qmd.ts:1473-1499`) only validates that old exists and new doesn't. It does NOT call `isValidCollectionName()`. Removed the false error case.
- **`qmd collection show` does NOT show ignore globs**: only `qmd collection list` does. Description and footer of `commands/collection-show.md` corrected. Verified at `src/cli/qmd.ts:3013-3037`.
- **`qmd status` does NOT show `[excluded]` tag**: only `qmd collection list` does. `commands/collection-include.md` and `commands/collection-exclude.md` previously recommended `/qmd:status` for verification — corrected to `/qmd:collection-show <name>` (which prints `Include: yes/no`).
- **YAML `context:` field is purely descriptive metadata**, NOT a scoring signal. Earlier docs falsely claimed "context terms scored at 0.3x weight when picking the best chunk." That weight (`INTENT_WEIGHT_SNIPPET = 0.3`, `INTENT_WEIGHT_CHUNK = 0.5` at `src/store.ts:3714-3717`) applies to the `intent` parameter, NOT to the YAML `context:` field. `getContextForPath()` (`src/store.ts:2394-2432`) only collects and concatenates context strings — they have zero influence on scoring. Rewrote `commands/context.md`.
- **MCP `status` tool response has no `includeByDefault`**: the search SKILL previously suggested using `mcp__qmd__status` to spot excluded collections. The MCP status response shape (`src/mcp/server.ts:47-58`) is `{name, path, pattern, documents, lastUpdated}` per collection — no include state. Now tells Claude to fall back to `qmd collection list` (CLI direct) if needed.
- **`add` SKILL `ignore:` recommendation**: previously listed 7-8 patterns that qmd already excludes by default. Verified hardcoded `excludeDirs = ["node_modules", ".git", ".cache", "vendor", "dist", "build"]` at BOTH `src/cli/qmd.ts:1504` AND `src/store.ts:1183`, plus the dotfile filter at `src/cli/qmd.ts:1529-1532` that excludes any path component starting with `.`. Slimmed the recommended list to only what qmd doesn't already exclude: `out/**`, `target/**`, `Pods/**`, test/snapshot patterns. Added a "what qmd already excludes" callout.
- **AST extension list** expanded to include `.mts/.cts/.mjs/.cjs` (verified at `src/ast.ts:34-48`).
- **HTTP transport multi-session support** (added in qmd 1.1.2) now noted in commands/mcp.md.
- **`--pull` is dead**: still in `parseArgs` at `src/cli/qmd.ts:2477` but never read in `updateCollections()` at `src/cli/qmd.ts:531-625`. Documented as such in commands/update.md.
- **Plugin version drift**: prior committed plugin had `marketplace.json` and `plugin.json` at `1.7.0` while `CHANGELOG.md` and README footer said `1.6.0`. All four now agree at `1.8.0`. The `1.7.0` CHANGELOG entry was backfilled in this release to capture the intermediate sync work that shipped without a changelog entry.
- **`.DS_Store`** files trashed. `.gitignore` already covered them.
- **`commands/embed.md`** claimed "embeds in batches of 32" — replaced with the actual `--max-docs-per-batch`/`--max-batch-mb` flags and defaults.

### Verified ✅ — full coverage of qmd v2.1.0 surface

Cross-referenced every CLI command, flag, MCP tool, MCP parameter, env var, YAML field, model URI, alias, and pipeline constant against `tobi/qmd@c2f3a40` by reading `src/cli/qmd.ts` (3,328 lines), `src/mcp/server.ts` (833 lines), `src/store.ts` (4,576 lines), `src/llm.ts` (1,587 lines), `src/collections.ts`, `src/maintenance.ts`, `src/bench/types.ts`, `src/bench/bench.ts`, `src/ast.ts`, `src/index.ts`, `package.json`, upstream `README.md`, and upstream `CLAUDE.md`.

- **Top-level CLI commands** (16): `bench`, `cleanup`, `embed`, `get`, `mcp`, `pull`, `query`, `search`, `status`, `update` → slash commands; `collection`, `context` → routing slash commands; `vsearch`, `ls`, `multi-get`, `skill` → intentionally not slash-commanded (see omissions list)
- **Collection subcommands** (8): `list` (bash fallback), `add` (covered by `/qmd:add` skill), `remove`/`rm`, `rename`/`mv`, `update-cmd`/`set-update`, `include`, `exclude`, `show`/`info`
- **Context subcommands** (3): `add`, `list`, `rm`/`remove` — all covered by `/qmd:context`. (Note: `qmd context check` from upstream's `CLAUDE.md` doesn't actually exist anymore — removed in qmd 1.1.0. Our docs correctly omit it; upstream's own `CLAUDE.md` is stale on this.)
- **MCP tools** (4): `query`, `get`, `multi_get`, `status` — all in `allowed-tools` of the search SKILL
- **MCP `query` parameters** (7): `searches`, `limit`, `minScore`, `candidateLimit`, `collections`, `intent`, `rerank`
- **MCP resource template** `qmd://{+path}` — registered automatically by the SDK
- **CLI flags**: search options (`-n`, `--min-score`, `--all`, `--full`, output formats, `--explain`, `-c/--collection` repeatable), collection options (`--name`, `--mask`), embed options (`-f/--force`, `--max-docs-per-batch`, `--max-batch-mb`, `--chunk-strategy`), update options (`--pull` DEAD, `--refresh`), get options (`-l`, `--from`, `--max-bytes`, `--line-numbers`), query options (`-C/--candidate-limit`, `--no-rerank`, `--intent`), MCP HTTP options (`--http`, `--daemon`, `--port`)
- **Env vars**: `QMD_EMBED_MODEL`, `QMD_RERANK_MODEL`, `QMD_GENERATE_MODEL`, `QMD_EMBED_CONTEXT_SIZE`, `QMD_RERANK_CONTEXT_SIZE`, `QMD_EXPAND_CONTEXT_SIZE`, `QMD_LLAMA_GPU`, `QMD_EDITOR_URI`, `XDG_CACHE_HOME`, `XDG_CONFIG_HOME`. Test-only `INDEX_PATH`/`QMD_CONFIG_DIR` correctly omitted.
- **YAML schema**: top-level `global_context`, `editor_uri`/`editor_uri_template`, `models.{embed,rerank,generate}`, `collections`; per-collection `path`, `pattern`, `ignore`, `update`, `includeByDefault`, `context` — all in `templates/index.yml`
- **Pipeline constants**: `CHUNK_SIZE_TOKENS=900`, `CHUNK_OVERLAP_TOKENS=135` (15%), `CHUNK_WINDOW_TOKENS=200`, `STRONG_SIGNAL_MIN_SCORE=0.85`, `STRONG_SIGNAL_MIN_GAP=0.15`, `RERANK_CANDIDATE_LIMIT=40`, top-rank bonuses (+0.05/+0.02), position-aware blending (75/60/40), RRF k=60, `INTENT_WEIGHT_SNIPPET=0.3`, `INTENT_WEIGHT_CHUNK=0.5`, reranker context 4096 + template overhead 512, AST-supported extensions
- **Hardcoded excludes** at `src/cli/qmd.ts:1504, 1529-1532` and `src/store.ts:1183` — documented in `add` SKILL with the "what qmd already excludes" callout
- **Bench**: fixture format (`{description, version, collection?, queries[]}`), per-query fields (`id`, `query`, `type`, `description`, `expected_files`, `expected_in_top_k`), 4 backends (`bm25`, `vector`, `hybrid` no-rerank, `full` with rerank), CLI flags (`--json`, `-c collection`)
- **GGUF model URIs**: `embeddinggemma-300M-Q8_0`, `qwen3-reranker-0.6b-q8_0`, `qmd-query-expansion-1.7B-q4_k_m` — exact match in `commands/pull.md`
- **Skill install paths** `~/.agents/skills/qmd` + optional `~/.claude/skills/qmd` symlink — README warning matches
- **Best-practices compliance** against [code.claude.com/docs/skills](https://code.claude.com/docs/skills) and [code.claude.com/docs/plugins-create](https://code.claude.com/docs/plugins-create): both SKILL.md files have YAML frontmatter with front-loaded descriptions, all under 250 chars; both SKILL.md files under 500 lines; supporting files referenced from SKILL.md; `add` SKILL uses `context: fork` + `agent: general-purpose`; `search` SKILL has `user-invocable: false` and `allowed-tools` listing MCP tool names; bash injection (`!`...``) used for live status; `${XDG_CONFIG_HOME}` interpolation used; `ultrathink` keyword in `add` SKILL; plugin name `qmd` namespaces all skills as `/qmd:<name>`; semver, MIT, repo, author, homepage fields all present; no `.DS_Store` files committed.

### Intentionally not in the plugin

These exist in qmd v2.1.0 but are deliberately omitted because they have no Claude story over the alternative:

- **`qmd vsearch`** — subset of `qmd query` with a `vec:` line, no advantage over typed query documents
- **`qmd ls` slash command** — Claude can run via Bash; the bash fallback in search SKILL mentions all forms (`qmd ls`, `qmd ls <collection>`, `qmd ls <collection>/<path>`)
- **`qmd collection list` slash command** — mentioned 6+ times as the bash fallback for `[excluded]` and ignore globs
- **`/qmd:multi-get` slash command** — MCP `mcp__qmd__multi_get` covers normal use; CLI fallback example added
- **`qmd skill install`/`show`** — would conflict with this plugin's bundled skill; README has a warning
- **`qmd --version`/`--skill`/`--context`** — trivial, alias-only, or DEAD
- **SDK / library usage** — different audience (Node/Bun apps embedding qmd), not Claude users
- **`Maintenance` SDK class** — `/qmd:cleanup` exposes the same operations to Claude
- **MCP HTTP REST endpoint quirks** — edge case for users running their own daemon

### Stats

| Metric | Pre-1.8.0 | 1.8.0 |
|---|---|---|
| Total plugin lines | 3,901 | ~1,500 |
| Slash commands | 22 | 17 |
| SKILL.md files | 2 (bloated) | 2 (lean) |
| `search` SKILL lines | 376 | 153 |
| `add` SKILL lines | 256 | 311 (local-mode branch) |
| Plugin-root reference docs | 5 (1,788 orphaned lines) | 0 |
| Stale claims | 12+ | 0 |
| Missing capabilities | 0 | 0 |

## 1.7.0

Sync with upstream [tobi/qmd](https://github.com/tobi/qmd) CLI 2.1.0. Adds intent disambiguation, AST chunking, query explain traces, no-rerank fast path, candidate-limit tuning, embed batch tuning, bench command, OSC 8 editor links, per-collection ignore globs, per-index models config, and the SDK / library mode.

### Added

#### Commands
- `/qmd:bench`: run search quality benchmarks against a fixture file (`qmd bench <fixture.json>`)

#### Search options (commands/query.md, MCP-SETUP.md, search SKILL.md)
- `--intent` flag and MCP `intent` parameter: disambiguate ambiguous queries (steers expansion, reranking, chunk selection, snippet extraction without searching on its own). Available as `intent:` line in query documents too.
- `--no-rerank` flag and MCP `rerank: false`: skip the reranker for fast results on CPU-only machines.
- `-C` / `--candidate-limit` flag and MCP `candidateLimit`: tune how many candidates reach the reranker (default 40).
- `--explain` flag: emit RRF + reranker score traces in JSON and CLI output.
- `--chunk-strategy auto|regex` (on `embed` and `query`): opt into AST-aware chunking for code files via tree-sitter (TypeScript, JavaScript, Python, Go, Rust). Markdown stays on regex.

#### Embed options
- `--max-docs-per-batch <n>`: cap docs loaded into memory per embedding batch
- `--max-batch-mb <n>`: cap UTF-8 MB loaded per embedding batch

#### Add skill
- Auto-write `ignore:` globs into the YAML on collection add (`node_modules`, `dist`, `build`, `target`, `.next`, `vendor`, etc.) so noise is excluded at index time.
- Pass `--chunk-strategy auto` to `qmd embed` for code repos so functions and classes get clean boundaries.

#### YAML config
- Per-collection `ignore: ["pattern", ...]` to exclude paths from indexing
- Top-level `models:` block with `embed`, `rerank`, `generate` URI overrides per index
- Top-level `editor_uri` / `editor_uri_template` for clickable OSC 8 terminal links in CLI output

#### Environment variables (architecture.md)
- `QMD_EMBED_MODEL`, `QMD_RERANK_MODEL`, `QMD_GENERATE_MODEL`: override built-in model URIs
- `QMD_EMBED_CONTEXT_SIZE`, `QMD_RERANK_CONTEXT_SIZE`, `QMD_EXPAND_CONTEXT_SIZE`: tune LLM context windows
- `QMD_LLAMA_GPU`: force a specific GPU backend
- `QMD_EDITOR_URI`: editor link template for clickable TTY search output

#### README
- SDK / library mode section with `createStore({dbPath, config})` examples
- New env var table

### Changed

#### Reranker context (models.md, architecture.md, pipeline.md)
- Default rerank context size: 2048 → 4096 (configurable via `QMD_RERANK_CONTEXT_SIZE`). Was hardcoded; upstream 2.1.0 widened it to fit longer chunks.
- Rerank template overhead: 200 → 512.

#### GPU detection (architecture.md, models.md)
- Replaced "manual CUDA > Metal > Vulkan probe" with node-llama-cpp's `build: "autoAttempt"`. ~220 lines of fallback code deleted upstream in 1.1.2. Priority is whatever node-llama-cpp picks; override with `QMD_LLAMA_GPU`.

#### MCP query tool (MCP-SETUP.md)
- Documents the full schema upstream now ships: `searches`, `collections`, `limit`, `minScore`, `candidateLimit`, `intent`, `rerank`. Previous version only documented 4 of the 7 params.

### Fixed

- Pipeline reference said reranker uses `rankAll()`. Source uses `rankAndSort()`. Corrected.
- `commands/embed.md` claimed "embeds in batches of 32" (a stale magic number). Replaced with the actual batch tuning flags.
- HTTP transport docs missed multi-session support (added in 1.1.2 PR #286). Now noted.
- Plugin version drift: `marketplace.json` and `plugin.json` were `1.7.0` while `CHANGELOG.md` and README footer were `1.6.0`. All four now agree at `1.7.0` (with a backfilled CHANGELOG entry).
- Trashed committed `.DS_Store` files. `.gitignore` already covered them.
- Reranker context size docs were 2048 (the pre-2.1.0 default). Now 4096 with `QMD_RERANK_CONTEXT_SIZE` override.
- Reranker template overhead was 200; actually 512 since 2.1.0 (`RERANK_TEMPLATE_OVERHEAD`).
- Pipeline reference said reranker uses `rankAll()`. Actual call is `rankAndSort()`.
- GPU detection priority claim ("CUDA > Metal > Vulkan") replaced with "node-llama-cpp `autoAttempt`" — upstream 1.1.2 deleted ~220 lines of manual fallback. Override via `QMD_LLAMA_GPU`.
- Embed batch defaults documented: 64 docs, 64 MB (whichever is hit first). Old "32" magic number was always wrong.
- AST chunking extension list expanded: `.ts/.tsx/.js/.jsx/.mts/.cts/.mjs/.cjs/.py/.go/.rs` (was missing `.mts/.cts/.mjs/.cjs`).

### Deeper sweep (post-first-pass)

- **MCP `get` and `multi_get` return `resource` content blocks**, not plain text. Documented in MCP-SETUP.md, search SKILL, commands/get.md, commands/multi-get.md. Claude Code surfaces resources as document attachments.
- **REST `POST /query` (alias `/search`) silently ignores `candidateLimit`, `rerank`, `chunkStrategy`** — only reads `searches`, `collections`, `limit`, `minScore`, `intent`. Documented as a quirk in MCP-SETUP.md.
- **MCP server tells LLMs "Always provide `intent` on every search call"** in dynamic instructions. Search SKILL.md now mirrors this as a standing rule (not optional), with examples of words that almost always need intent.
- **MCP `query` tool path skips LLM query expansion** because typed sub-queries are already provided (`structuredSearch`, not `hybridQuery`). CLI `qmd query "plain text"` is the only path that runs expansion. Documented in pipeline.md, search SKILL.md, commands/query.md.
- **Model lifecycle differs between CLI and MCP/SDK**:
  - CLI: `disposeModelsOnInactivity = false` (default). Contexts disposed on idle, models stay in VRAM.
  - SDK / MCP: `disposeModelsOnInactivity = true` (forced by `createStore()`). Contexts AND models disposed on idle. Cold start ~3-8s on next request.
  - Documented in models.md, architecture.md, README SDK section.
- **Bench command fixture format was wrong.** Real format: `{description, version, collection?, queries: [{id, query, type, description, expected_files, expected_in_top_k}]}`. Each query has `type` (`exact|semantic|topical|cross-domain|alias`), `expected_files` (paths, not docids), and `expected_in_top_k`. The 4 backends are `bm25`, `vector`, `hybrid` (no rerank), `full` (with rerank). Bench accepts `--json` and `-c collection`.
- **Collection subcommand aliases documented**: `show`/`info`, `update-cmd`/`set-update`. README CLI Extras updated.
- **Warning: do NOT run `qmd skill install`.** Upstream 2.0.1+ packages its own skill into `~/.agents/skills/qmd` with an optional symlink at `~/.claude/skills/qmd`. Conflicts with this plugin's bundled skill. Use `qmd skill show` to compare without writing.
- **SDK `Maintenance` class** added to README's SDK section with usage example.
- **Runtime versions pinned**: `node-llama-cpp@3.18.1`, `@modelcontextprotocol/sdk@1.29.0`, `better-sqlite3@12.8.0`, `sqlite-vec@0.1.9`. Upstream pins all deps to exact versions starting in 2.1.0.

## 1.6.0

Clarify MCP vs CLI type availability across all docs. MCP `query` only accepts `lex`, `vec`, `hyde`. The `expand:` type and plain text auto-expansion are CLI-only.

### Changed

#### Search skill
- Split modality table into "Typed queries (MCP + CLI)" and "Auto-expand (CLI only)" rows
- Add Availability column to sub-query types table, marking `expand:` and plain text as CLI-only
- Add MCP type enum note to grammar section: `"lex" | "vec" | "hyde"`
- Update examples to use typed MCP queries instead of plain text auto-expand
- Fix recommended workflow: remove `**Bold:**` inline-header formatting
- Fix query examples to show `searches` array with `{type, query}` objects

#### Add skill
- Remove `**Bold:** description` formatting from Known Limitations bullet list

#### Pipeline reference
- Clarify `expand:` and plain text auto-expansion are CLI-only, not MCP
- Fix full hybrid latency table: show `lex`+`vec`+`hyde` with "(CLI also: `expand:`)" note
- Add CLI-only annotation to expansion grammar EBNF comment

#### Commands
- `query.md`: add "(CLI only)" to `expand:` type, note MCP accepts `lex`/`vec`/`hyde` only
- `search.md`: fix description and MCP equivalent to use `{type: "lex"}` format
- `vsearch.md`: fix description and MCP equivalent to use `{type: "vec"}` format
- `update.md`: remove `**CRITICAL:**` prefix (voice rule)

#### Reference docs
- `MCP-SETUP.md`: remove `expand` from MCP query tool type list (MCP only accepts `lex`/`vec`/`hyde`)
- `MCP-SETUP.md`: replace `expand` example with `hyde` example showing keyword + semantic + hypothetical pattern
- `MCP-SETUP.md`: remove `expand:` from dynamic server instructions latency list
- `MCP-SETUP.md`: fix troubleshooting tip that referenced `expand:` as an MCP option
- `models.md`: remove `**Bold:**` inline-header formatting from text formatting bullets

#### Root docs
- `plugin.json`: add `version: "1.6.0"` field
- `README.md`: clarify MCP `query` types (`lex`, `vec`, `hyde`) vs CLI `expand:`
- `README.md`: bump version to 1.6.0

## 1.5.0

- Add `/reload-plugins` note to README for picking up changes without restart
- Add MCP dedup note to MCP-SETUP.md: plugin `.mcp.json` handles config, avoid duplicate `settings.json` entry
- Verify `description` and `argument-hint` fields present in all SKILL.md frontmatter
- Verify MCP configuration (.mcp.json) is current
- Replace all emdashes with commas, colons, and periods

## 1.4.0 (2026-02-20)

Sync with upstream [tobi/qmd](https://github.com/tobi/qmd) v1.0.8. MCP tools consolidated, query document format, lex syntax, new collection management commands.

### Added

#### Commands
- `/qmd:collection-show`: display collection details (path, pattern, update command, contexts, includeByDefault)
- `/qmd:collection-update-cmd`: set pre-update shell command for a collection (replaces direct YAML editing)
- `/qmd:collection-include`: include a collection in default queries
- `/qmd:collection-exclude`: exclude a collection from default queries (`includeByDefault: false`)

### Changed

#### MCP (breaking)
- MCP tools `search`, `vector_search`, `deep_search` removed. Replaced by single `query` tool
- MCP `collection` string parameter replaced by `collections` array (multi-collection filter)
- HTTP endpoint renamed from `/search` to `/query` (`/search` kept as silent alias)

#### Search skill
- Rewrite for single `query` tool: modality table, tools table, MCP/CLI reference, examples all updated
- Add "Query Document Format" section: typed sub-queries (`lex:`, `vec:`, `hyde:`, `expand:`), EBNF grammar
- Add "Lex Syntax" section: quoted phrases (`"exact match"`), negation (`-term`, `-"phrase"`)
- First sub-query gets 2x fusion weight. Documented in modality and pipeline reference
- `collections` array replaces single `collection` parameter throughout

#### Pipeline reference
- Add query document format with EBNF grammar and examples
- Add lex query sub-grammar (phrase, negation, word operators)
- Add `expand:` type to expansion grammar
- Note first sub-query gets 2x weight in RRF fusion

#### Add skill
- Step 5 now uses `qmd collection update-cmd` instead of direct YAML config editing
- Remove `Read` and `Edit` from allowed-tools (no longer needed)
- Add `Bash(qmd collection*)` to allowed-tools
- Remove "Direct config editing" from Known Limitations
- Update Recovery table: "Config edit failed" → "Update-cmd failed"

#### Commands
- `query.md`: now primary MCP tool, add query document format and lex syntax notes
- `search.md`: mark as CLI-only (MCP `search` tool removed), reference `query` with `lex:` prefix
- `vsearch.md`: mark as CLI-only (MCP `vector_search` tool removed), reference `query` with `vec:` prefix
- `context.md`: remove `check` subcommand (removed upstream)
- `status.md`: add actionable tips note, update version to 1.0.8
- `collection-list.md`: add `[excluded]` tag for collections with `includeByDefault: false`

#### References
- `cli-reference.md`: add query document format, lex syntax, new collection subcommands (show, update-cmd, include, exclude), remove `context check`, update MCP section, version bump
- `architecture.md`: add `includeByDefault` field to YAML format, add lex query syntax to FTS5 section, add `collections` array parameter note

#### README
- Update MCP tool list (`query`, `get`, `multi_get`, `status`)
- Add 4 new collection commands to command table
- Remove `context check` from examples
- Update "How Add Works" step 5 for `collection update-cmd`
- Version bump to 1.4.0

### Fixed (verified against upstream v1.0.8 source)

- Fix BM25 normalization formula: was incorrectly documented as sigmoid `1/(1+exp(-(|x|-5)/3))` in v1.3.0, actual source uses `|x|/(1+|x|)` (verified: store.ts:2120). Fixed in cli-reference.md (2 locations), pipeline.md, architecture.md
- Fix GPU priority order: was "Metal > CUDA > Vulkan", actual source is CUDA > Metal > Vulkan (verified: llm.ts:505-506). Fixed in architecture.md and models.md
- Fix MCP `query` tool parameter: documented as `query` string, actual param is `searches` array of `{type, query}` objects (verified: mcp.ts:243-308). Fixed in SKILL.md
- Fix `get.md` claiming Levenshtein suggestions in CLI: only MCP `get` does fuzzy matching, CLI prints "Document not found"
- Fix `collection-show.md` claiming file count/last updated: CLI `show` doesn't display these fields
- Fix `status.md` referencing `set-update-cmd`: correct command name is `update-cmd`
- Fix `rename.md` claiming regex validation on new name: not enforced in CLI code
- Remove `--no-lex` from dead flags: flag was fully removed from parser (not just dead)
- Rewrite MCP-SETUP.md "Available MCP Tools" section: was documenting removed `search`, `vector_search`, `deep_search` tools. Now documents `query` with `searches` array, `get`, `multi_get`, `status`
- Fix MCP-SETUP.md curl example: was using `"name":"search"`, now uses `"name":"query"` with `searches` array
- Fix MCP-SETUP.md troubleshooting: was referencing `search`/`deep_search`, now references `query` sub-query types
- Fix MCP-SETUP.md dynamic instructions: was listing old tool escalation ladder, now lists `query` sub-query types with latencies
- Fix MCP-SETUP.md "Choosing" table: was listing old tool names, now lists `query`, `get`, `multi_get`, `status`
- Fix pipeline.md latency table: was using old MCP tool names as column headers, now shows CLI command + MCP sub-query type
- Fix pipeline.md chunk breakpoint scores: H4/code block were merged (70-80), H5-H6/HR were merged (50-60). Now separate rows matching source: H4=70, code block=80, H5=60, H6=50, HR=60
- Fix pipeline.md stale tool references: `vector_search` and `deep_search` replaced with CLI command names

## 1.3.0 (2026-02-16)

Sync with upstream [tobi/qmd](https://github.com/tobi/qmd) v1.0.6. Full source audit of all 10k+ lines.

### Added

#### Commands
- `/qmd:embed`: generate or refresh vector embeddings with force flag
- `/qmd:pull`: download or verify GGUF models from HuggingFace
- `/qmd:get`: retrieve documents by path, docid, or virtual path (CLI fallback)
- `/qmd:multi-get`: retrieve multiple documents by glob or comma list (CLI fallback)
- `/qmd:search`: BM25 keyword search (CLI fallback)
- `/qmd:vsearch`: vector/semantic search (CLI fallback)
- `/qmd:query`: hybrid deep search with reranking (CLI fallback)
- `/qmd:mcp`: start, stop, and manage MCP server daemon
- `/qmd:collection-add`: standalone `qmd collection add` for local directories
- `/qmd:collection-list`: list all collections with metadata

#### References
- `references/cli-reference.md`: complete CLI reference covering every command and flag
- `references/architecture.md`: SQLite schema, content-addressable storage, hybrid search pipeline
- `references/models.md`: detailed reference for 3 GGUF models (embed, rerank, expand)
- `skills/search/references/pipeline.md`: hybrid search pipeline internals (RRF, blending, chunking)

#### Skills
- Add `agent: general-purpose` frontmatter to both skills
- Add `<role>` definition and `ultrathink` to add skill
- Add formal `## Arguments` section to add skill (matches commit/audit/techdebt pattern)
- Add `## Constraints` section to add skill (replaces weaker `## Conventions`)
- Add `## Known Limitations` section to add skill (private repos, shallow clones, config coupling)
- Expand `## Recovery` in add skill with situation/recovery table
- Add `model: sonnet` to search skill (explicit model declaration)
- Add pre-loaded state (`!` commands) to search skill
- Add `## Recovery` table to search skill (MCP disconnects, zero results, timeouts)
- Extract pipeline internals to `skills/search/references/pipeline.md`
- Wrap search examples in `<examples>` XML tags with structured scenarios

#### Add skill
- Add `--dest` flag to override clone destination (default `~/Developer/refs/`)
- Replace hardcoded `~/Developer/refs/` with `$REFS` variable throughout
- Use `${XDG_CONFIG_HOME:-~/.config}/qmd/index.yml` instead of hardcoded `~/.config`
- Update update command to use full git path: `git -C <path> pull --ff-only`
- Add `qmd pull` for manual model download
- Add Node.js 22+ runtime requirement

#### Docs
- Document MCP Resource registration (`qmd://{+path}`) in MCP-SETUP reference
- Add MCP HTTP transport section to README
- Update install instructions: `npm install -g @tobilu/qmd` or `bun install -g @tobilu/qmd`
- Add Node.js 22+ and `qmd pull` to requirements
- Add XDG_CONFIG_HOME and XDG_CACHE_HOME support throughout
- Add CLI extras section: `--version`, `--line-numbers`, output formats, CLI aliases, multiple `-c` filters
- Document smart chunking (scored markdown breakpoints, code fence protection)
- FTS5 query sanitization rules (strips non-alphanumeric except apostrophes, prefix matching)
- Snippet extraction ±100 char context window
- Session manager dual-counter coordination (activeSessionCount + inFlightOperations)
- Operation timeouts: embed 30min, vector/deep search 10min, BM25 search 2min

### Changed

#### MCP
- Remove `qmd_` prefix from all MCP tool names. Upstream dropped prefix in v0.9.0 (MCP namespaces by server). Actual tools: `search`, `vector_search`, `deep_search`, `get`, `multi_get`, `status`
- Document MCP HTTP transport (`qmd mcp --http [--daemon] [--port N]`, `qmd mcp stop`)
- Document dynamic server instructions (index state injected into LLM system prompt at startup)
- Update MCP-SETUP.md with new tool names, HTTP transport, and Node.js install path

#### Search pipeline
- Update chunking from 800 → 900 tokens with 15% overlap and scored markdown breakpoints
- Document GRPO fine-tuned query expansion model (replaces stock Qwen3-1.7B)
- Add type-routed expansion: lex (BM25 keywords), vec (semantic rephrasings), hyde (hypothetical documents)
- Add conditional expansion (skipped when BM25 returns strong signal)
- Document RRF original query 2x weight + top-rank bonus +0.05
- Add GPU parallelism note (parallel contexts, flash attention, adaptive parallelism)

#### Commands
- Rewrite all 7 existing command files with detail from official QMD codebase
- Expand search skill with CLI fallback section, named indexes, and additional tips
- Expand pipeline reference with expansion grammar, embedding format, session timeouts
- Update MCP-SETUP reference with named indexes, dynamic instructions, HTTP response format examples
- Tighten `allowed-tools` in list command (`Bash(qmd ls*)` instead of `Bash(qmd *)`)
- Tighten `allowed-tools` in update command (scoped to `qmd update*` and `qmd embed*`)
- Rewrite status command: GPU info, model URIs, MCP daemon status, vector index details
- Rewrite update command: YAML-based workflow, custom update commands
- Rewrite list command: ls -l style output with colors and timestamps
- Rewrite context command: filesystem path auto-detection, collection root paths
- Rewrite cleanup command: 4-step cleanup (cache, orphaned vectors, inactive docs, vacuum)

### Fixed (verified against upstream v1.0.6 source)

#### Critical
- Fix BM25 normalization formula: was `|x|/(1+|x|)`, actual is sigmoid `1/(1+exp(-(|x|-5)/3))` (verified: `qmd.ts:1736`)
- Fix BM25 parameters docs: FTS5 `bm25()` takes column weights (filepath=10.0, title=1.0, body=1.0), NOT k1/b params (k1=1.2, b=0.75 are SQLite-hardcoded)
- Add exact position-aware blending formula: `blendedScore = rrfWeight * (1/rrfRank) + (1 - rrfWeight) * rerankerScore` (verified: `store.ts:2950-2954`)

#### MCP & tools
- Fix `get` tool description: add "suggests similar files if not found" (fuzzy suffix matching)
- Fix `multi_get` tool description: add "skips files larger than maxBytes"
- Fix vector dimensions description: table is created lazily via `ensureVecTable()` on first embed

#### Pipeline
- Fix `hyde` routing: vector only, not both BM25+vector (upstream routes lex→BM25, vec/hyde→vector)
- Remove incorrect multi-chunk score aggregation claim (upstream picks single best chunk per doc)
- Fix RRF weight description: first 2 result lists (BM25 + vector) get 2x, not just "original query"
- Add RRF k=60 value and rank bonuses: +0.05 for rank 0, +0.02 for ranks 1-2
- Add RERANK_CANDIDATE_LIMIT = 40
- Add strong signal thresholds: score >= 0.85, gap >= 0.15
- Note `vector_search` also uses query expansion (vec/hyde only)
- Fix chunker break priority: headers > code blocks > paragraph boundaries > list items
- Add latency expectations: search ~30ms, vector_search ~2s, deep_search ~10s
- Add BM25 scoring details: filepath 10x weight, Porter stemmer, normalization formula
- Add HuggingFace repo paths for all 3 models

#### Docs
- Fix context resolution docs: all matching path prefixes are concatenated (global → root → specific), not "most specific wins"
- Fix `collection add --name` described as required: it's optional (auto-generated from directory name via `handelize()`)
- Fix LLM cache eviction: probabilistic pruning (1% chance, deletes oldest 900), not "LRU max 1000"
- Fix reranker model size inconsistency: ~640MB everywhere (was ~490MB)
- Fix model names from source: embeddinggemma-300M (Q8_0), qwen3-reranker-0.6b (Q8_0), qmd-query-expansion-1.7B (Q4_K_M)
- Remove stale `qmd update --pull` from CLI reference examples: flag is parsed but ignored upstream
- Remove `--no-lex` from CLI extras: dead flag
- Fix `--pull` documentation: flag is parsed but ignored upstream
- Remove claim that `qmd update <collection-name>` targets specific collections: upstream always updates all
- Fix context add syntax: `qmd://collection/` not `<name>:/`
- Fix cleanup step count: 4 steps not 5
- Fix README version footer (was stuck at 1.0.0 since normalization)
- Update example-index.yml with 2026 journal year and full git paths in update commands

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
- MCP server with 6 tools: search, vector_search, deep_search, get, multi_get, status
- `/qmd:add` skill for repo onboarding with auto-detection
- Search guide skill (model-invocable background knowledge)
- 7 commands: cleanup, context, list, remove, rename, status, update

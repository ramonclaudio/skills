# Changelog

## 1.4.0 — 2026-02-20

Sync with upstream [tobi/qmd](https://github.com/tobi/qmd) v1.0.8. MCP tools consolidated, query document format, lex syntax, new collection management commands.

### Added

#### Commands
- `/qmd:collection-show` — display collection details (path, pattern, update command, contexts, includeByDefault)
- `/qmd:collection-update-cmd` — set pre-update shell command for a collection (replaces direct YAML editing)
- `/qmd:collection-include` — include a collection in default queries
- `/qmd:collection-exclude` — exclude a collection from default queries (`includeByDefault: false`)

### Changed

#### MCP (breaking)
- MCP tools `search`, `vector_search`, `deep_search` removed — replaced by single `query` tool
- MCP `collection` string parameter replaced by `collections` array (multi-collection filter)
- HTTP endpoint renamed from `/search` to `/query` (`/search` kept as silent alias)

#### Search skill
- Rewrite for single `query` tool — modality table, tools table, MCP/CLI reference, examples all updated
- Add "Query Document Format" section — typed sub-queries (`lex:`, `vec:`, `hyde:`, `expand:`), EBNF grammar
- Add "Lex Syntax" section — quoted phrases (`"exact match"`), negation (`-term`, `-"phrase"`)
- First sub-query gets 2x fusion weight — documented in modality and pipeline reference
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
- `query.md` — now primary MCP tool, add query document format and lex syntax notes
- `search.md` — mark as CLI-only (MCP `search` tool removed), reference `query` with `lex:` prefix
- `vsearch.md` — mark as CLI-only (MCP `vector_search` tool removed), reference `query` with `vec:` prefix
- `context.md` — remove `check` subcommand (removed upstream)
- `status.md` — add actionable tips note, update version to 1.0.8
- `collection-list.md` — add `[excluded]` tag for collections with `includeByDefault: false`

#### References
- `cli-reference.md` — add query document format, lex syntax, new collection subcommands (show, update-cmd, include, exclude), remove `context check`, update MCP section, version bump
- `architecture.md` — add `includeByDefault` field to YAML format, add lex query syntax to FTS5 section, add `collections` array parameter note

#### README
- Update MCP tool list (`query`, `get`, `multi_get`, `status`)
- Add 4 new collection commands to command table
- Remove `context check` from examples
- Update "How Add Works" step 5 for `collection update-cmd`
- Version bump to 1.4.0

### Fixed (verified against upstream v1.0.8 source)

- Fix BM25 normalization formula — was incorrectly documented as sigmoid `1/(1+exp(-(|x|-5)/3))` in v1.3.0, actual source uses `|x|/(1+|x|)` (verified: store.ts:2120). Fixed in cli-reference.md (2 locations), pipeline.md, architecture.md
- Fix GPU priority order — was "Metal > CUDA > Vulkan", actual source is CUDA > Metal > Vulkan (verified: llm.ts:505-506). Fixed in architecture.md and models.md
- Fix MCP `query` tool parameter — documented as `query` string, actual param is `searches` array of `{type, query}` objects (verified: mcp.ts:243-308). Fixed in SKILL.md
- Fix `get.md` claiming Levenshtein suggestions in CLI — only MCP `get` does fuzzy matching, CLI prints "Document not found"
- Fix `collection-show.md` claiming file count/last updated — CLI `show` doesn't display these fields
- Fix `status.md` referencing `set-update-cmd` — correct command name is `update-cmd`
- Fix `rename.md` claiming regex validation on new name — not enforced in CLI code
- Remove `--no-lex` from dead flags — flag was fully removed from parser (not just dead)
- Rewrite MCP-SETUP.md "Available MCP Tools" section — was documenting removed `search`, `vector_search`, `deep_search` tools. Now documents `query` with `searches` array, `get`, `multi_get`, `status`
- Fix MCP-SETUP.md curl example — was using `"name":"search"`, now uses `"name":"query"` with `searches` array
- Fix MCP-SETUP.md troubleshooting — was referencing `search`/`deep_search`, now references `query` sub-query types
- Fix MCP-SETUP.md dynamic instructions — was listing old tool escalation ladder, now lists `query` sub-query types with latencies
- Fix MCP-SETUP.md "Choosing" table — was listing old tool names, now lists `query`, `get`, `multi_get`, `status`
- Fix pipeline.md latency table — was using old MCP tool names as column headers, now shows CLI command + MCP sub-query type
- Fix pipeline.md chunk breakpoint scores — H4/code block were merged (70-80), H5-H6/HR were merged (50-60). Now separate rows matching source: H4=70, code block=80, H5=60, H6=50, HR=60
- Fix pipeline.md stale tool references — `vector_search` and `deep_search` replaced with CLI command names

## 1.3.0 — 2026-02-16

Sync with upstream [tobi/qmd](https://github.com/tobi/qmd) v1.0.6. Full source audit of all 10k+ lines.

### Added

#### Commands
- `/qmd:embed` — generate or refresh vector embeddings with force flag
- `/qmd:pull` — download or verify GGUF models from HuggingFace
- `/qmd:get` — retrieve documents by path, docid, or virtual path (CLI fallback)
- `/qmd:multi-get` — retrieve multiple documents by glob or comma list (CLI fallback)
- `/qmd:search` — BM25 keyword search (CLI fallback)
- `/qmd:vsearch` — vector/semantic search (CLI fallback)
- `/qmd:query` — hybrid deep search with reranking (CLI fallback)
- `/qmd:mcp` — start, stop, and manage MCP server daemon
- `/qmd:collection-add` — standalone `qmd collection add` for local directories
- `/qmd:collection-list` — list all collections with metadata

#### References
- `references/cli-reference.md` — complete CLI reference covering every command and flag
- `references/architecture.md` — SQLite schema, content-addressable storage, hybrid search pipeline
- `references/models.md` — detailed reference for 3 GGUF models (embed, rerank, expand)
- `skills/search/references/pipeline.md` — hybrid search pipeline internals (RRF, blending, chunking)

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
- Remove `qmd_` prefix from all MCP tool names — upstream dropped prefix in v0.9.0 (MCP namespaces by server). Actual tools: `search`, `vector_search`, `deep_search`, `get`, `multi_get`, `status`
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
- Fix BM25 normalization formula — was `|x|/(1+|x|)`, actual is sigmoid `1/(1+exp(-(|x|-5)/3))` (verified: `qmd.ts:1736`)
- Fix BM25 parameters docs — FTS5 `bm25()` takes column weights (filepath=10.0, title=1.0, body=1.0), NOT k1/b params (k1=1.2, b=0.75 are SQLite-hardcoded)
- Add exact position-aware blending formula: `blendedScore = rrfWeight * (1/rrfRank) + (1 - rrfWeight) * rerankerScore` (verified: `store.ts:2950-2954`)

#### MCP & tools
- Fix `get` tool description — add "suggests similar files if not found" (fuzzy suffix matching)
- Fix `multi_get` tool description — add "skips files larger than maxBytes"
- Fix vector dimensions description — table is created lazily via `ensureVecTable()` on first embed

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
- Fix context resolution docs — all matching path prefixes are concatenated (global → root → specific), not "most specific wins"
- Fix `collection add --name` described as required — it's optional (auto-generated from directory name via `handelize()`)
- Fix LLM cache eviction — probabilistic pruning (1% chance, deletes oldest 900), not "LRU max 1000"
- Fix reranker model size inconsistency — ~640MB everywhere (was ~490MB)
- Fix model names from source: embeddinggemma-300M (Q8_0), qwen3-reranker-0.6b (Q8_0), qmd-query-expansion-1.7B (Q4_K_M)
- Remove stale `qmd update --pull` from CLI reference examples — flag is parsed but ignored upstream
- Remove `--no-lex` from CLI extras — dead flag
- Fix `--pull` documentation — flag is parsed but ignored upstream
- Remove claim that `qmd update <collection-name>` targets specific collections — upstream always updates all
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

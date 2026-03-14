# QMD Architecture

Internal storage, search, and retrieval architecture.

## SQLite Schema

All data stored in a single SQLite database: `~/.cache/qmd/index.sqlite` (or `~/.cache/qmd/<name>.sqlite` for named indexes).

### Tables

#### content

Content-addressable storage. SHA-256 deduplication. Same content = one row, referenced by multiple documents.

| Column | Type | Constraints |
|--------|------|-------------|
| hash | TEXT | PRIMARY KEY |
| doc | TEXT | NOT NULL |
| created_at | TEXT | NOT NULL |

**Indexes:** None (hash is PK)

#### documents

Document metadata. Multiple documents can reference the same hash (dedup across collections).

| Column | Type | Constraints |
|--------|------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT |
| collection | TEXT | NOT NULL |
| path | TEXT | NOT NULL |
| title | TEXT | NOT NULL |
| hash | TEXT | FOREIGN KEY → content.hash |
| created_at | TEXT | NOT NULL |
| modified_at | TEXT | NOT NULL |
| active | INTEGER | DEFAULT 1 |

**Indexes:**
- `idx_documents_collection` on `(collection, active)`
- `idx_documents_hash` on `(hash)`
- `idx_documents_path` on `(path, active)`

**Unique constraint:** `(collection, path)`

**Soft deletes:** `active` flag (0 = deleted, 1 = active). Allows rollback and preserves history.

#### documents_fts

FTS5 virtual table for full-text search.

```sql
CREATE VIRTUAL TABLE documents_fts USING fts5(
  filepath,
  title,
  body,
  tokenize='porter unicode61'
);
```

**Tokenizer:** Porter stemmer + Unicode 6.1 (handles accents, non-ASCII)

**Column weights (BM25):**
- `filepath`: 10.0 (path matching heavily weighted)
- `title`: 1.0
- `body`: 1.0

**Triggers (auto-sync):**
- `documents_ai`: INSERT -> populate FTS
- `documents_au`: UPDATE -> update FTS
- `documents_ad`: DELETE -> remove from FTS

#### content_vectors

Vector chunk metadata.

| Column | Type | Constraints |
|--------|------|-------------|
| hash | TEXT | NOT NULL |
| seq | INTEGER | NOT NULL |
| pos | INTEGER | NOT NULL |
| model | TEXT | NOT NULL |
| embedded_at | TEXT | NOT NULL |

**Primary key:** `(hash, seq)`

**Chunking:** 900 tokens/chunk, 15% overlap (135 tokens), `seq` is chunk index, `pos` is start position in original document.

#### vectors_vec

sqlite-vec virtual table for vector storage.

```sql
CREATE VIRTUAL TABLE vectors_vec USING vec0(
  hash_seq TEXT PRIMARY KEY,
  embedding float[N],
  distance_metric=cosine
);
```

**Composite key:** `hash_seq` = `{hash}_{seq}` (e.g., `abc123_0`)

**Dimensions:** Dynamic, table created lazily on first embed via `ensureVecTable()`, using actual dimensions from the embedding model (768 for embeddinggemma-300M). Table recreated if model changes.

**Distance metric:** Cosine similarity

**CRITICAL:** Never JOIN directly on this table. sqlite-vec hangs on JOINs. Always query `vectors_vec` first, collect results, then query documents separately.

**Two-step query pattern:**
```sql
-- Step 1: Query vectors_vec
SELECT hash_seq, distance FROM vectors_vec WHERE embedding MATCH ? ORDER BY distance LIMIT 100;

-- Step 2: Parse hash_seq, query documents
SELECT * FROM documents WHERE hash IN (extracted_hashes);
```

#### llm_cache

LLM response cache for query expansion and reranking.

| Column | Type | Constraints |
|--------|------|-------------|
| hash | TEXT | PRIMARY KEY |
| result | TEXT | NOT NULL |
| created_at | TEXT | NOT NULL |

**Auto-pruning:** Probabilistic eviction. On each cache write, 1% chance to keep only the newest 1000 entries (deletes everything outside the top 1000 by `created_at`).

**Hash:** SHA-256 of prompt + model + temperature + topK + topP.

### Legacy Table Cleanup

On every database init, QMD drops two legacy tables from the pre-YAML era:

```sql
DROP TABLE IF EXISTS path_contexts;
DROP TABLE IF EXISTS collections;
```

Context and collections now live in `~/.config/qmd/index.yml` (managed by `collections.ts`).

### Pragmas

```sql
PRAGMA journal_mode = WAL;      -- Write-Ahead Logging for concurrency
PRAGMA foreign_keys = ON;        -- Enforce FK constraints
```

## Content-Addressable Storage

**SHA-256 hashing:** Document content hashed, stored once in `content` table. Multiple `documents` rows can reference the same hash.

**Deduplication:** Same file in multiple collections → one `content` row, multiple `documents` rows.

**Soft deletes:** Setting `documents.active = 0` preserves content. Orphaned content (no active document references) removed by `qmd cleanup`.

**Docid format:** `#` + first 6 hex chars of hash (e.g., `#abc123`). Stable reference across path changes.

## FTS5 Configuration

**Tokenization:** Porter stemmer (English word stemming: "running" → "run") + Unicode 6.1 tokenizer (handles accents, non-ASCII).

**Query sanitization:** Each search term is stripped of all characters except letters, numbers, and apostrophes (`[^\p{L}\p{N}']` removed). Each sanitized term is wrapped as a prefix match (`"term"*`).

**Column weights (BM25 `bm25()` function arguments, NOT k1/b parameters):**
- `filepath`: 10.0 (boosts path/filename matches)
- `title`: 1.0
- `body`: 1.0

Example: Searching for "middleware" matches `next.js/middleware.ts` with 10x weight vs. "middleware" in document body.

**Lex query syntax (query documents):** When using `lex:` type in query documents, two special syntaxes apply:
- **Quoted phrases** (`"rate limit"`) bypass prefix matching and perform exact phrase search against FTS5.
- **Negation** (`-term`) excludes documents containing the term (maps to FTS5 `NOT`).

**BM25 scoring:** Built-in FTS5 BM25 with fixed k1=1.2, b=0.75 (SQLite hardcoded, not configurable). Raw scores normalized to 0-1 range.

**Normalization formula:**
```
normalized_score = |raw_score| / (1 + |raw_score|)
// strong(-10) → 0.91, medium(-2) → 0.67, weak(-0.5) → 0.33, none(0) → 0
```

## Vector Storage

**sqlite-vec extension:** C extension, cosine distance, kNN search.

**Composite key:** `hash_seq` = `{hash}_{seq}` (e.g., `abc123_0` for first chunk of document `abc123`).

**Two-step query approach (CRITICAL):**

sqlite-vec hangs on JOINs. Always:
1. Query `vectors_vec` first with `WHERE embedding MATCH ?`
2. Collect `hash_seq` results
3. Parse hash from `hash_seq`
4. Query `documents` separately with `WHERE hash IN (...)`

**Example:**
```sql
-- WRONG (hangs)
SELECT d.* FROM documents d
JOIN vectors_vec v ON v.hash_seq = d.hash || '_' || seq
WHERE v.embedding MATCH ?;

-- RIGHT
-- Step 1
SELECT hash_seq FROM vectors_vec WHERE embedding MATCH ? LIMIT 100;
-- Step 2 (in application)
const hashes = results.map(r => r.hash_seq.split('_')[0]);
-- Step 3
SELECT * FROM documents WHERE hash IN (hashes);
```

## Smart Chunking

**Constants (exported from `store.ts`):**

| Constant | Value | Description |
|----------|-------|-------------|
| `CHUNK_SIZE_TOKENS` | 900 | Tokens per chunk |
| `CHUNK_OVERLAP_TOKENS` | 135 | 15% overlap |
| `CHUNK_SIZE_CHARS` | 3600 | Char approximation (~4 chars/token) |
| `CHUNK_OVERLAP_CHARS` | 540 | Char overlap approximation |
| `CHUNK_WINDOW_TOKENS` | 200 | Search window for breakpoints |
| `CHUNK_WINDOW_CHARS` | 800 | Char window approximation |
| `DEFAULT_GLOB` | `**/*.md` | Default file pattern for collections |
| `DEFAULT_MULTI_GET_MAX_BYTES` | 10240 (10KB) | Skip files larger than this in multi_get |

**Breakpoint scoring:**

| Break Type | Score |
|------------|-------|
| H1 (`# ...`) | 100 |
| H2 (`## ...`) | 90 |
| H3 (`### ...`) | 80 |
| H4 (`#### ...`) | 70 |
| Code block start/end | 80 |
| H5 (`##### ...`) | 60 |
| H6 (`###### ...`) | 50 |
| Horizontal rule (`---`) | 60 |
| Blank line (paragraph boundary) | 20 |
| Unordered list item (`- `, `* `) | 5 |
| Ordered list item (`1. `, `2. `) | 5 |
| Newline | 1 |

**Distance decay:** Quadratic with factor 0.7. Score decays as distance from ideal split point increases.

**Formula:**
```
final_score = base_score * (1 - (distance / window_size)^2 * 0.7)
```

**Code fence protection:** Code blocks (```` ``` ````) never split mid-block. If ideal split falls inside a code fence, the chunker moves to the next valid breakpoint after the fence.

**Overlap calculation:** Next chunk starts at `current_chunk_start + chunk_size - overlap`. This means chunk boundaries overlap by 135 tokens to preserve context across chunks.

**Snippet extraction:** When extracting snippets from matched documents, a ±100 character context window is applied around the chunk position to avoid cutting mid-sentence.

## Hybrid Search Pipeline

8-step pipeline combining keyword, semantic, and LLM signals.

**MCP `collections` parameter:** The MCP `query` tool accepts a `collections` array (e.g., `["next.js", "react"]`) instead of a single `collection` string. Collections with `includeByDefault: false` are excluded unless explicitly listed in the array.

### 1. BM25 Probe

Run original query against FTS5. If strong signal detected (top score >= 0.85 AND gap to second result >= 0.15), skip expansion entirely.

**Constants and detection logic:**
```
STRONG_SIGNAL_MIN_SCORE = 0.85
STRONG_SIGNAL_MIN_GAP = 0.15
```

```ts
const topScore = initialFts[0]?.score ?? 0;
const secondScore = initialFts[1]?.score ?? 0;
const hasStrongSignal = initialFts.length > 0
  && topScore >= STRONG_SIGNAL_MIN_SCORE
  && (topScore - secondScore) >= STRONG_SIGNAL_MIN_GAP;
```

### 2. Query Expansion

If no strong signal, use GRPO-optimized query expansion model (qmd-query-expansion-1.7B-q4_k_m) to generate 3 types of sub-queries:

| Type | Backend | Example |
|------|---------|---------|
| `lex` | BM25 only | "authentication middleware handler" |
| `vec` | Vector only | "how request authentication is validated" |
| `hyde` | Vector only | "The middleware checks the JWT token..." |

**Grammar constraint:**
```
root ::= line+
line ::= type ": " content "\n"
type ::= "lex" | "vec" | "hyde"
```

**Validation:** Each expansion must contain at least one term from original query.

**Fallback:** On expansion failure, returns `[{type: 'vec', text: originalQuery}]`.

### 3. Type-Routed Search

Batch searches by type:
- `lex` queries → BM25 only
- `vec` and `hyde` queries → Vector only via single `llm.embedBatch()` call (one LLM call for all vector queries, not sequential `embed()` calls)

Eliminates wasted backend calls (~10 → 6 per query).

### 4. RRF Fusion

Reciprocal Rank Fusion with k=60. Weights:
- Original BM25 results: 2x
- Original vector results: 2x
- Expanded query results: 1x each

**Top-rank bonuses:**
- Rank 0 (top): +0.05
- Ranks 1-2: +0.02

**Top-K selection:** Top 40 candidates (RERANK_CANDIDATE_LIMIT) pass to reranking.

### 5. Smart Chunking

For each candidate document, select the best chunk by keyword overlap with query. One chunk per document (no aggregation).

**Chunk window:** 200 tokens around query term matches.

### 6. LLM Reranking

Send best chunk per document to cross-encoder reranker (qwen3-reranker-0.6b-q8_0).

**Context window:** 2048 tokens (fixed, allows ~800 token chunks + ~200 token template + query)

**Native ranking context:** Uses node-llama-cpp's native ranking (no custom prompt).

**Returns:** Scores 0-1, higher = more relevant.

### 7. Position-Aware Blending

Blend RRF retrieval scores with reranker scores using position-aware weights:

| RRF Rank | Retrieval Weight | Reranker Weight | Reason |
|----------|-----------------|-----------------|--------|
| 1-3 | 75% | 25% | Protect exact keyword matches |
| 4-10 | 60% | 40% | Balanced |
| 11+ | 40% | 60% | Trust reranker more |

**Formula:** `blendedScore = rrfWeight * (1/rrfRank) + (1 - rrfWeight) * rerankerScore`

**Why:** Top keyword matches stay near top even if reranker prefers a semantically similar but different document.

### 8. Deduplication

Remove duplicate documents (same hash). Keep highest-scoring instance.

## Virtual Paths

**Format:** `qmd://collection/path/to/file.md`

**Purpose:** Stable references across filesystem changes. Used in context management.

**Resolution:** ``get`` resolves `qmd://` URIs to actual filesystem paths via collection config.

## Configuration

**Database:** `~/.cache/qmd/index.sqlite` (default) or `~/.cache/qmd/<name>.sqlite` (named index)

**Config:** `~/.config/qmd/index.yml` (default) or `~/.config/qmd/<name>.yml` (named index)

**XDG support:** Respects `XDG_CONFIG_HOME` (config dir) and `XDG_CACHE_HOME` (database dir).

**Environment overrides:**
- `INDEX_PATH`: override database path entirely (used in tests)
- `QMD_CONFIG_DIR`: override config directory (used in tests)

**Production mode:** `enableProductionMode()` must be called before `createStore()` when using default paths. Without it, QMD requires an explicit path or `INDEX_PATH` env var. This prevents tests from accidentally writing to the global index.

**Named indexes:** Use `--index <name>` for separate work/personal collections.

## Collections Module (`collections.ts`)

All YAML-based collection management lives in `collections.ts`. `store.ts` delegates to it for collection CRUD:

| Function | Purpose |
|----------|---------|
| `loadConfig()` / `saveConfig()` | Read/write `~/.config/qmd/{index}.yml` |
| `getCollection(name)` | Get single collection config |
| `listCollections()` | List all collections |
| `addCollection(name, path, pattern)` | Add or update collection (default pattern: `**/*.md`) |
| `removeCollection(name)` | Remove from YAML |
| `renameCollection(old, new)` | Rename in YAML |
| `addContext()` / `removeContext()` | Per-path context CRUD |
| `getGlobalContext()` / `setGlobalContext()` | Global context across all collections |
| `findContextForPath(collection, filePath)` | Most specific prefix match (deepest only) |
| `listAllContexts()` | All contexts across all collections |
| `isValidCollectionName(name)` | Validates `^[a-zA-Z0-9_-]+$` |

**Config path resolution:** `QMD_CONFIG_DIR` env var > `XDG_CONFIG_HOME/qmd` > `~/.config/qmd`

## Collection YAML Format

```yaml
# Global context applied to all collections
global_context: "If you see a [[WikiWord]], search for it to get more context."

# Collection definitions
collections:
  next.js:
    path: ~/Developer/refs/next.js
    pattern: "**/*.{md,mdx,txt,ts,tsx,js,jsx,json,yaml,yml,css}"
    update: "git -C ~/Developer/refs/next.js pull --ff-only"
    context:
      "/": "Next.js framework source code and documentation"
      "/docs": "Official Next.js documentation"
      "/packages/next/src": "Core Next.js runtime source"

  notes:
    path: ~/Documents/Notes
    pattern: "**/*.md"
    includeByDefault: false
    context:
      "/": "Personal notes and ideas"
      "/journal/2024": "Daily notes from 2024"
```

**Fields:**
- `path`: Absolute path to collection directory (tilde-expanded)
- `pattern`: Glob pattern for file inclusion (e.g., `**/*.md`)
- `update`: Shell command to run before re-indexing (e.g., `git pull`)
- `includeByDefault`: Boolean (default: `true`). When `false`, the collection is excluded from queries unless explicitly targeted with `-c`. Set via `qmd collection exclude`/`include`.
- `context`: Hierarchical path → description map (all matching prefixes concatenated)

**Context resolution (all matching prefixes concatenated):**

`store.ts:getContextForPath()` collects ALL matching prefixes and joins with `\n\n`. This is what search and MCP use. (`collections.ts:findContextForPath()` returns only the deepest match but is not called by search/MCP.)

All matching contexts are collected and joined with `\n\n`, from most general to most specific:
1. `global_context` (if defined)
2. All matching path prefix contexts, sorted shortest→longest

**Example:** Query hits `qmd://next.js/docs/api-reference.md`:
- `global_context` → **included** (always first if defined)
- `/` context exists → **included** (root context)
- `/docs` context exists → **included** (matches prefix)
- `/docs/api` context exists → **included** (matches prefix)

All four are joined with `\n\n` and returned as the document's context.

## Path Resolution

When ``get`` receives a path:

1. **Docid:** `#abc123` → lookup by hash in `content` table
2. **Virtual path:** `qmd://collection/path` → resolve via collection config
3. **Collection prefix:** `next.js/docs/api.md` → lookup collection, resolve path
4. **Absolute filesystem:** `/Users/name/file.md` → direct read
5. **Relative filesystem:** `docs/api.md` → resolve from cwd
6. **Suffix match:** `api.md` → find any document path ending with `api.md` (fallback, may be ambiguous)

Use docids for stable references, collection-prefixed paths for clarity.

## Session Management

**Inactivity timeout:** 5 minutes (`DEFAULT_INACTIVITY_TIMEOUT_MS = 5 * 60 * 1000`). LlamaContext instances disposed, models kept loaded. Timeout fires only when both `activeSessionCount=0` AND `inFlightOperations=0`.

**Operation timeouts:** Embedding: 30 minutes. Vector/deep search: 10 minutes. BM25 search: 2 minutes (default).

**Model persistence:** GGUF models stay loaded in VRAM across sessions unless `disposeModelsOnInactivity=true`.

**Context reuse:** HTTP daemon mode (`qmd mcp --http --daemon`) keeps models warm, reducing first-query latency (~16s → ~10s).

## GPU Auto-Detection

**Priority:** CUDA > Metal > Vulkan > CPU fallback

**Parallel contexts:** 1-8 LlamaContext instances based on VRAM availability (25% free VRAM reserved per context).

**Flash attention:** Enabled by default for reranker (~568MB/context vs 711MB without). Falls back to standard attention if flash fails.

**CPU mode:** Uses `std::thread::hardware_concurrency()` split across contexts, minimum 4 threads per context.

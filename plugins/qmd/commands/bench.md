---
description: Run search quality benchmarks against a fixture file. Reports precision/recall/MRR/F1 across 4 backends.
allowed-tools: Bash(qmd bench*)
argument-hint: <fixture.json> [--json] [-c collection]
---

Run `qmd bench $ARGUMENTS`. Compares 4 backends on the same labeled queries:

- `bm25`: BM25 keyword only
- `vector`: vector cosine only
- `hybrid`: BM25 + vector RRF fusion (no LLM reranker)
- `full`: full hybrid pipeline (with LLM reranker)

Reports precision@k, recall, MRR, and F1 per backend so you can quantify how much the reranker buys you over plain BM25 on the user's specific corpus.

Flags:
- `--json`: machine-readable output instead of the human table
- `-c <name>`: override the fixture's `collection` field

Fixture format is `{description, version, collection?, queries: [{id, query, type, description, expected_files, expected_in_top_k}]}`. Each query has a `type` (`exact|semantic|topical|cross-domain|alias`) for grouping in the report and `expected_files` (paths relative to the collection) for scoring. Upstream ships an example at `src/bench/fixtures/example.json`.

Use this for A/B-testing config changes (`--candidate-limit`, `--chunk-strategy`, model overrides) and for catching regressions after `qmd update`.

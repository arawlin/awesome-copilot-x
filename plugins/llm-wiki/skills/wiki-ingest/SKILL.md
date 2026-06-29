---
name: wiki-ingest
description: Ingest raw documents into the LLM Wiki — read files from raw/, extract entities and concepts, generate structured wiki pages (sources/entities/concepts) with mandatory provenance. Use when user asks to "ingest documents", "add to wiki", "process raw files", or build the knowledge base from source materials.
argument-hint: "[--source <file>] [--all]"
---

# Wiki Ingest — 文档摄入

Read documents from `raw/`, extract knowledge, and generate structured wiki pages under `wiki/sources/`, `wiki/entities/`, and `wiki/concepts/`.

## Prerequisites

- The `llm-wiki` repo must be accessible via `$LLM_WIKI_PATH` environment variable.
- Read `plugins/instructions/llm-wiki-schema.instructions.md` for the page format specification.
- Read `wiki/.wiki-config.yml` for dedup thresholds and security rules.

## Workflow

### Step 1: Scan raw/ directory

List all files in `$LLM_WIKI_PATH/raw/`. If the user specifies `--source <file>`, process only that file. Otherwise process all unprocessed files.

### Step 2: Read and extract (single-pass + inline self-validation)

For each document:

1. **Read** the document content fully.
2. **Extract** in a single pass:
   - **Entities**: Named identifiable things (tools, frameworks, companies, people, protocols, platforms). Generate `wiki/entities/<slug>.md`.
   - **Concepts**: Abstract ideas, patterns, methodologies. Generate `wiki/concepts/<slug>.md`.
   - **Relations**: Links between entities and concepts.
3. **Generate source page**: `wiki/sources/<source-slug>.md` with summary, key points, entity list, concept list.
4. **Self-validate** inline:
   - Every claim MUST have provenance (quote or paraphrase with source reference).
   - Assign confidence: `high` (directly stated), `medium` (reasonably inferred), `low` (speculative → requires human review).
   - Tag unsupported claims with `[unverified]`.

**Extraction rules:**
- Prefer completeness over precision — "rather extract more than miss something."
- Preserve original text snippets for provenance.
- Mark uncertainty explicitly — never fabricate.
- **Dedup check** (per `.wiki-config.yml` thresholds):
  - Level 1: Exact slug match → AUTO-UPDATE (same source, 100% confidence).
  - Level 2: Fuzzy title match > 85% → AUTO-MERGE (same source).
  - Level 3: Semantic similarity > 0.75 → SUGGEST-MERGE (create merge suggestion).
  - No match → CREATE new page.

### Step 3: Deduplication (five-band decision matrix)

| Band | Condition | Action |
|------|-----------|--------|
| 0 | Slug exact match + same source + 100% confidence | AUTO-UPDATE existing page |
| 1 | Fuzzy title > 85% + same source | AUTO-MERGE into existing page |
| 2 | Semantic > 0.75 | SUGGEST-MERGE (create `questions_pending/merge-*.md`) |
| 3 | No match | CREATE new page |
| 4 | Contradiction detected | FLAG (create `contradictions_pending/*.md`) |

### Step 4: Security filter

Before writing any page, apply three-layer defense:

1. **LLM semantic check**: Scan extracted content for credentials, PII, network topology, trade secrets, infrastructure details. If `sensitive` level detected → REJECT, do not generate.
2. **gitleaks regex**: Run `gitleaks detect --source <content> --config $LLM_WIKI_PATH/.gitleaks.toml` on generated pages.
3. **pre-commit hook**: Relies on the repo's `.git/hooks/pre-commit` gitleaks check.

### Step 5: Write pages and update index

1. Write source page to `wiki/sources/<slug>.md`.
2. Write entity pages to `wiki/entities/<slug>.md`.
3. Write concept pages to `wiki/concepts/<slug>.md`.
4. Update `wiki/index.md` page directory (append new pages under appropriate sections).
5. Append operation record to `wiki/log.md` in JSON Lines format.

### Page Limits

- Maximum **15 pages** per ingest run (1 source + up to 7 entity + up to 7 concept).
- If a document would generate more, split into multiple ingest sessions.

## Output Format

After ingestion, summarize:
- Documents processed: N
- Source pages created: N
- Entity pages created: N
- Concept pages created: N
- Merge suggestions: N
- Contradictions flagged: N
- Sensitive content blocked: N

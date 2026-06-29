---
name: wiki-bootstrap
description: Bootstrap a new LLM Wiki from a GitHub repository — extract knowledge from README, docs/, issues, and PRs using 4-level priority extraction. Target: 3 startup questions answerable, minimum 11 pages. Use when user asks to "bootstrap wiki", "initialize wiki from repo", or start a fresh knowledge base.
argument-hint: "[--repo <path>] [--phases <A|AB|ABC>]"
---

# Wiki Bootstrap — 冷启动引导

Initialize a new LLM Wiki from an existing GitHub repository.

## Prerequisites

- Target repo must be accessible locally.
- The `llm-wiki` repo must be accessible via `$LLM_WIKI_PATH` environment variable.
- Read `plugins/instructions/llm-wiki-schema.instructions.md` for page format.

## Extraction Phases (4-level priority)

### Phase A: Overview Seed (P0 — required)

**Sources**: `README.md`

Extract:
- **1 source page**: README summary.
- **3–6 entity pages**: Core tools, frameworks, services mentioned.
- **3–6 concept pages**: Key patterns, architecture concepts.

**Target**: 7–13 pages. This is the minimum viable wiki.

### Phase B: Constraint Seed (P1 — recommended)

**Sources**: `docs/` directory (all `.md` files)

Extract additional entities and concepts from documentation. Merge/update Phase A pages.

**Target**: Additional 5–15 pages.

### Phase C: Community Seed (P2 — optional, opt-in)

**Sources**: High-engagement Issues (👍 ≥ 5)

Extract pain points, feature requests, and workarounds as concept/decision pages.

**Target**: Additional 3–8 pages.

### Phase D: Decision Seed (P3 — optional, opt-in)

**Sources**: Merged PRs (title + description)

Extract architectural decisions and rationale.

**Target**: Additional 2–5 pages.

## Workflow

### Step 1: Scan the target repository

Read the repo structure. Present a summary:

```
📊 Repository Analysis:
   Language: <detected>
   README: <size>
   Docs: <n> files in docs/
   Issues: <n> open, <n> high-engagement
   Merged PRs: <n> recent

Estimated bootstrap: Phase A = 7–13 pages, Phase AB = 12–28 pages
Proceed with [A|AB|ABC|full]?
```

### Step 2: Execute extraction (phase by phase)

For each phase, use the same extraction logic as `/wiki-ingest`:
1. Read source documents.
2. Extract entities, concepts, decisions.
3. Generate wiki pages with provenance.
4. Self-validate (confidence levels).
5. Security filter.

### Step 3: Batch confirmation

After extraction, present ALL generated pages as a batch (not one by one):

```
📦 Bootstrap Complete: <N> pages generated
   Sources: <n>
   Entities: <n>
   Concepts: <n>

Page list:
   [[entities/foo]] — Foo
   [[concepts/bar]] — Bar
   ...

Review and approve all? [y/n/edit]
```

This compresses the human-gated loop into a single batch confirmation.

### Step 4: Startup validation

After approval, run 3 pre-defined startup questions:

1. "What is this project?" — Should return project overview from source page.
2. "What are the core concepts?" — Should list concepts from concept pages.
3. "How do I get started?" — Should return setup/quickstart from README source.

Scoring: ≥ 2/3 correct = bootstrap successful.

If bootstrap fails (< 2/3), suggest running Phase B (docs/) for more content.

### Step 5: Finalize

1. Update `wiki/index.md` with all new pages.
2. Append bootstrap record to `wiki/log.md`.
3. Update `memories/wiki-activity.md`.
4. Report:
   ```
   ✅ Bootstrap successful!
      Pages: <N>
      Startup Q&A: <score>/3
      Wiki is ready for queries. Try /wiki-query "what is this project?"
   ```

## Constraints

- Maximum total pages: **50 per bootstrap session**.
- Minimum viable: **11 pages** (1 source + 5 entity + 5 concept).
- Issues/PRs phases are **opt-in only** — never scrape without user consent.
- Human-gated: batch confirmation required before finalizing.

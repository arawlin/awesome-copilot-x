---
name: wiki-ingest
description: 'Ingest approved content into the LLM Wiki — read raw/ documents (knowledge map + entity/concept extraction) and approved session capture documents from questions_approved/ (type-splitting + dedup), producing self-contained wiki pages (sources/entities/concepts) with mandatory provenance and LLM-consumption quality rules (self-containment, size caps, progressive disclosure). Use when user asks to "ingest documents", "add to wiki", "process raw files", or build the knowledge base for AI agents.'
argument-hint: "[--source <file>] [--all]"
---

# Wiki Ingest — 文档摄入

Read documents from `raw/` and approved session capture documents from `questions_approved/`, then generate structured wiki pages under `wiki/sources/`, `wiki/entities/`, and `wiki/concepts/`. Session documents are type-split here (entity / concept) — capture deliberately does not classify, because type assignment needs the global dedup and granularity context this stage owns. The wiki is consumed by **LLM agents**, not human readers: agents retrieve pages on demand into a finite context window, so every page must be self-contained and every index must stay small and high-signal. Extracted pages are leaf nodes of a lightweight document knowledge map — never isolated fragments, never bloated megapages.

## When to Use This Skill

- 用户要求"摄入文档"、"add to wiki"、"处理 raw 文件"
- 从原始材料（API 全文、研究笔记、技术文档）构建知识库
- 需要把已有知识去重、归类、建立关联时

## Prerequisites

- The `llm-wiki` repo must be accessible via `$LLM_WIKI_PATH` environment variable.
- Read the instruction file `llm-wiki-schema.instructions.md` for the page format specification.
- Read `wiki/.wiki-config.yml` for dedup thresholds and security rules.

## Workflow

### Step 1: Scan raw/ directory

List all files in `$LLM_WIKI_PATH/raw/`. If the user specifies `--source <file>`, process only that file. Otherwise process all unprocessed files.

### Step 2: Build the document knowledge map (before extraction)

**Do this before extracting anything.** Read the document fully, then produce a knowledge map that captures the document's overall structure — this is the anti-fragmentation anchor.

**Use the FIXED template** defined in `llm-wiki-schema.instructions.md`（Source 页面 → 知识地图）— write it verbatim into the source page's `## 知识地图` section. Do not invent your own structure; the schema is the single source of truth.

**How to fill each block:**
- **核心主题**: One sentence — what knowledge domain does this document cover?
- **章节骨架**: The document's chapters → sections, in order.
- **知识块映射**: For each knowledge block, classify:
  - **类型 (type)**: `pattern` / `mechanism` (knowledge) vs `data` (parameter table, error listing — reference only)
  - **检索价值 (retrieval value)**: `standalone` (queried alone → page) or `context-only` (meaningful only in context → merge into parent / stay in source)
  - **归属 (home)**: the page it lands in (`[[concepts/<id>]]` / `[[entities/<id>]]`), a `#anchor` within a parent page, or `本页` (stays in this source page)
- **块间依赖**: which blocks each block references or builds upon, with the relation type.

The knowledge map is the **document-level llms.txt** — a small, high-signal index that lets an agent navigate the document without loading it whole. Keep it lean: one-line core theme, skeleton at chapter level only, one row per knowledge block. Never let it grow into a restatement of the document. Every extracted page must link back to it. Blocks marked `本页` or `#anchor` stay in the source / parent page and never become standalone pages.

### Step 3: Decide page granularity (LLM-consumption optimized)

Use the knowledge map from Step 2 to decide what becomes a page. **The consumer is an LLM**: retrieval works best when a single page fully answers one query without pulling unrelated tokens. Entities and concepts use DIFFERENT standards:

**Entities (具名事物) — relaxed: any named, identifiable thing may become a page.**
- Entity pages are thin (definition + attributes + sources) and act as cross-document identity anchors. Even low-reuse entities (e.g., a CLI tool) are worth a page because future documents are likely to reference the same name.
- Do NOT create entity pages for unnamed / abstract notions — those are concepts.

**Concepts (抽象知识) — strict: a concept becomes a page ONLY if ALL three hold:**
1. **Has standalone retrieval value** — an LLM is likely to query this idea on its own (e.g., an auth scheme, a rate-limiting strategy). Sub-flows that only make sense inside a parent topic do NOT qualify. **Heuristic**: can this block answer a real retrieval question in one sentence on its own? ✅ "Binance 如何限频？" → rate-limiting (standalone)；❌ "签名流程的第一步是什么？" → merge into authentication (sub-flow, never queried alone).
2. **Self-contained** — it can be fully understood from this page alone, without pulling sibling pages. This is a hard requirement for LLM retrieval.
3. **Knowledge, not data** — it is a pattern, principle, or mechanism (why/how), not a parameter table or listing (what).

**Otherwise, do NOT create a separate page:**
- **Sub-flows and sub-mechanisms with no standalone retrieval value** belong in their parent page as a `## section` (anchor). Example: "signature payload construction" is a sub-flow of "API authentication" — if it is never queried alone, merge it in.
- **Doc-specific details** with low reuse stay in the source page's knowledge map (marked `本页`).
- **Parameter tables, comparison matrices, error code listings, change logs** are data, not knowledge — skip entirely. They live in the raw document; agents fetch raw files just-in-time for "what".

**Granularity principle: 自包含优先，允许原子化，杜绝重复与低信号（self-containment first; atomicity is fine; no duplication, no low-signal pages).** When unsure, prefer the smaller self-contained page over merging topics — a bloated page pollutes retrieval with unrelated tokens. But never create a page that duplicates another page, or that an agent would not query alone.

> This is deliberately OPPOSITE to the dedup policy (宁多勿少). Dedup prevents **duplicate** knowledge (expensive in a finite context window); granularity prevents **bloat and non-self-containment**. Apply each rule to its own decision — never mix them up.

### Step 4: Extract entities and concepts (single-pass + inline self-validation)

For each document, guided by the knowledge map and granularity rules:

1. **Entities**: Named identifiable things (tools, frameworks, companies, people, protocols, platforms). Generate `wiki/entities/<slug>.md` — any named, identifiable thing qualifies (relaxed standard, see Step 3).
2. **Concepts**: Abstract ideas, patterns, methodologies. Generate `wiki/concepts/<slug>.md` — only concepts meeting the three strict conditions in Step 3.
3. **Relations**: Link entities and concepts with **structured semantic relations** in `related` (YAML):

   ```yaml
   related:
     # Structured (preferred): relation type + target + optional note
     - { relation: part-of, target: binance-api-authentication, note: "签名 payload 构建是鉴权体系的子流程" }
     # Simple reference (backward compatible): bare id
     - binance-api-types-comparison
   ```

   `relation` enum: `part-of` / `contains` / `causes` / `contrasts-with` / `instance-of` / `relates-to`. Never use bare links when a semantic relation is known.
4. **Generate source page**: `wiki/sources/<source-slug>.md` with summary, key points, the **knowledge map** (Step 2), entity list, concept list.
5. **Self-validate** inline:
   - Every claim MUST have provenance (quote or paraphrase with source reference).
   - Assign confidence: `high` (directly stated), `medium` (reasonably inferred), `low` (speculative → requires human review).
   - Tag unsupported claims with `[unverified]`.
   - **Every page must be self-contained**: a reader (LLM) pulling this page alone understands it without fetching siblings. If not, fold in the missing context or link it explicitly.
   - **Respect the size cap** (calibrated by live run): entity/concept ≤ 150 lines / ~2KB, source ≤ 200 lines / ~6KB (see schema). Exceeding it means split by retrieval intent or compress.

### Knowledge Extraction Principles

Wiki stores **knowledge** (why, how, patterns), not raw data (what, specs, parameters). Apply this decision matrix before extracting:

| Reuse / Change | Low change rate | High change rate |
|---------------|-----------------|------------------|
| **High reuse** | ✅ Extract as concept | ⚠️ Patterns only, skip parameter tables |
| **Low reuse** | ⚠️ Optional, low priority | ❌ Skip entirely |

Examples:

- ✅ **Extract**: auth mechanisms, rate limiting strategy, API type architecture, stream type patterns, local order book algorithm
- ❌ **Skip**: endpoint parameter tables, full error code listings, change logs, quick-start copy-paste
- 💡 Endpoint parameters live in raw `llms-full.txt` — AI agents query that directly for "what", Wiki answers "why" and "how".

**Extraction rules:**
- Prefer **patterns and principles** over exhaustive enumeration — extract the "why" and "how to use", not "what are all the parameters".
- Preserve original text snippets for provenance.
- Mark uncertainty explicitly — never fabricate.
- **Dedup check** (LLM 语义判断，宁多勿少):
  - Level 1: Exact slug match → AUTO-UPDATE existing page (same source).
  - Level 2: LLM 语义判断 — 对比候选页面 title/内容，判断是否为同一实体/概念：
    - 明显同一 → MERGE into existing page（合并内容，保留两条 provenance）。
    - 疑似同一但不确定 → SUGGEST-MERGE（创建 `questions_pending/merge-*.md`）。
    - 无匹配 → CREATE new page.
  - 不确定时创建新页面（宁多勿少）—— 合并错误的代价远大于合并重复。

### Step 5: Deduplication (simplified three-band)

| Band | Condition | Action |
|------|-----------|--------|
| 0 | Slug exact match + same source | AUTO-UPDATE existing page |
| 1 | LLM 语义判断为同一实体/概念 | MERGE into existing page；不确定 → SUGGEST-MERGE (`questions_pending/merge-*.md`) |
| 2 | No match | CREATE new page |
| 3 | Contradiction detected | FLAG (create `contradictions_pending/*.md`) |

> 依赖说明：去重不再依赖 RapidFuzz / SBERT（`all-MiniLM-L6-v2` 为英文模型，中文语义相似度不可靠）。语义判断由 LLM 完成。

### Step 6: Security filter

1. **LLM semantic check**（主力）: Scan extracted content for credentials, PII, network topology, trade secrets, infrastructure details. If `sensitive` level detected → REJECT, do not generate.
2. **gitleaks (optional)**: If gitleaks is installed, run `gitleaks detect --source <content> --config $LLM_WIKI_PATH/.gitleaks.toml` on generated pages. Skip if not installed.
3. **pre-commit hook (optional)**: If present, `.git/hooks/pre-commit` runs a gitleaks scan and skips gracefully when gitleaks is missing.

### Step 7: Write pages and update index

1. Write source page to `wiki/sources/<slug>.md` — **must include the knowledge map** (core theme, section skeleton, block→page mapping, block dependencies) and the **raw-document query block** (progressive disclosure to the original).
2. Write entity pages to `wiki/entities/<slug>.md` — end with a one-line **detail pointer** to its source page / original document (progressive disclosure).
3. Write concept pages to `wiki/concepts/<slug>.md` — end with a one-line **detail pointer** to its source page / original document (progressive disclosure).
4. Fill `related` with semantic relations (see Step 4.3), and add back-links from every extracted page to its source page.
5. **Optional cross-document synthesis** (draft): create a `wiki/synthesis/` page only when a question spans multiple source pages and no single page answers it — the manual equivalent of GraphRAG's community summary. Do NOT use synthesis to restate a single document (its knowledge map already covers that). Synthesis pages require human approval (`approved_by`) — ingest only produces the draft, review approves it.
6. Update `wiki/index.md` — the **whole-wiki llms.txt**: append new pages in the standard llms.txt line format `- [title](<type>/<id>.md): one-line description` (see schema, Index 节), grouped by type/theme, with an `Optional` section for low-priority links. The split threshold is a **1M-token context window**: only when the index exceeds 1M tokens do you split it into topic-level index pages (MOC-style).
7. Append operation record to `wiki/log.md` in JSON Lines format.

## Session Capture Ingestion（会话文档摄入）

Second input source, after raw documents: `questions_approved/session-*.md` (one document per capture run, format per schema「Session Capture」节). This stage owns the type-splitting that capture deliberately skipped.

For each session document:

1. **Type-split each item**:
   - **Entity** (named, identifiable thing) → `wiki/entities/<slug>.md` (relaxed standard, Step 3).
   - **Concept** (pattern/methodology) → `wiki/concepts/<slug>.md` only if the three-condition granularity gate passes; sub-flows fold into the parent page as a `## section` (`#锚点`).
   - Rationale content ("we chose X over Y because Z") is part of a concept's 核心思想 — it arrives as a concept candidate, never a separate class.
2. **Dedup check** per item — same three-band table as Step 5 (AUTO-UPDATE / MERGE / SUGGEST-MERGE / CREATE).
3. **Security filter** per Step 6.
4. **Provenance**: every claim in the final page must carry the session document id (`captured_from`) — keep the trail from session → page.
5. Update `wiki/index.md` and `wiki/log.md` (Step 7).

### Page Limits

- Maximum **15 pages** per ingest run (1 source + up to 7 entity + up to 7 concept) — default value; override via `wiki/.wiki-config.yml` (`ingest_max_pages_per_run`). Session-document items count against this same limit.
- If a document would generate more, first re-apply Step 3 (drop data tables, merge sub-flows with no standalone retrieval value); if the remaining pages are all self-contained with distinct retrieval value, split the ingest into multiple sessions rather than forcing merges.

## Gotchas

- **Never split sub-flows with no standalone retrieval value into pages.** A sub-flow (e.g., signature payload construction) that is never queried alone is part of its parent concept (authentication) — a separate page fragments navigation without retrieval benefit. Merge into the parent page as a `## section`.
- **Never extract parameter tables, comparison matrices, or error listings as concepts.** They are data, not knowledge. Duplicating them into wiki pages creates stale copies and page bloat; the raw document is their home.
- **A source page is not a summary-only page.** It must carry the document's knowledge map. Without it, extracted pages become orphaned fragments with no whole-picture anchor.
- **Do not use bare flat links as relations.** `related: [binance-api-authentication, binance-request-signing-payload]` does not say how the two relate. Use structured semantic relations (see Step 4.3).
- **Apply 自包含优先 (granularity) and 宁多勿少 (dedup) to different decisions.** Dedup prevents duplicate knowledge (expensive in a finite context window); granularity prevents bloat and non-self-containment. Reversing them pollutes retrieval or duplicates knowledge.
- **One page, one retrieval intent.** If a page needs its background restated to be understood, it is not self-contained — fold in the missing context or link it explicitly.
- **Keep the knowledge map and index small.** They are llms.txt-style navigation, not content. If an index cannot fit a context window, split it into topic-level maps.
- **Never exceed the page size cap.** A bloated page pollutes retrieval with unrelated tokens (context rot) — split by retrieval intent or compress to high-signal statements.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| A document generates too many candidate pages | Re-apply Step 3: drop data tables, merge sub-flows with no standalone retrieval value, keep only independently queryable blocks |
| Two extracted pages overlap heavily | They are one concept — merge into one page, keep both provenances; if distinct retrieval value remains, record a semantic relation instead |
| A page is hard to understand without its source | It is not self-contained — fold in the missing context, or link it explicitly (progressive disclosure) |
| A page exceeds the size cap | Split the page by retrieval intent, or compress the prose to high-signal statements |
| The index page no longer fits a context window | Split `index.md` into topic-level MOC pages and keep a slim root index |

## References

- `llm-wiki-schema.instructions.md` — page format, frontmatter, WikiLink syntax
- `wiki-context.instructions.md` — cross-session context, `$LLM_WIKI_PATH` conventions

## Output Format

After ingestion, summarize:
- Documents processed: N
- Source pages created: N
- Entity pages created: N
- Concept pages created: N
- Merge suggestions: N
- Contradictions flagged: N
- Sensitive content blocked: N

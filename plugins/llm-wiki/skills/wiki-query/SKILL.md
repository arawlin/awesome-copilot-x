---
name: wiki-query
description: 'Query the LLM Wiki knowledge base — read wiki/index.md for directory, selectively load relevant pages, synthesize answers with [[WikiLink]] citations. Use when user asks questions that may be answered by wiki knowledge, wants to "search the wiki", or needs cross-referenced information from the knowledge base.'
argument-hint: "<question>"
---

# Wiki Query — 知识查询

Answer user questions by reading and synthesizing information from the LLM Wiki knowledge base.

## Prerequisites

- The `llm-wiki` repo must be accessible via `$LLM_WIKI_PATH` environment variable.
- Read the instruction file `llm-wiki-schema.instructions.md` for WikiLink syntax and page structure.

## Workflow

### Step 1: Read the index

Read `$LLM_WIKI_PATH/wiki/index.md` to get the full page directory. Parse:
- All pages grouped by type (sources / entities / concepts / synthesis) and tags.
- Page titles and IDs for relevance matching.

### Step 2: Select relevant pages

Based on the user's question, identify candidate pages:

1. **BM25 pre-filter (large wikis only)**: If `wiki/index.md` exceeds ~20K tokens or the wiki has more than ~5,000 pages, run the bundled search script instead of scanning the whole index:
   ```bash
   python3 <skill-dir>/scripts/search.py "<question>" --top-k 15
   ```
   The script prints ranked `[[<type>/<id>]]` candidates with scores — use these as the candidate set and skip steps 2–4.
2. **Index scan**: Read `wiki/index.md` (whole-wiki llms.txt, entries in standard llms.txt line format) — match question terms against page titles, tags, and IDs.
3. **Knowledge map navigation**: For the matching domain, read the relevant `sources/` page's `## 知识地图` to locate the exact knowledge block (and its home page) instead of guessing from titles.
4. **Semantic relevance**: Prefer pages whose title/tags overlap with question domain.
5. **Selection budget**: Select at most **10–15 pages** to stay within token budget (target: 1,500–12,000 tokens for page content).

### Step 2.5: Check source page for raw fallback instruction

Wiki concept/entity pages store **knowledge** (why, how, patterns). They deliberately omit **reference data** that lives in the original source document.

1. Read the relevant `sources/` page for the topic domain.
2. If the source page contains an `Agent 指令` block with a `fetch_webpage` URL, use that URL as the canonical reference for detail-level information not covered in Wiki pages.
3. This is not domain-specific — it applies to any source (API docs, technical specs, protocol standards, etc.) where Wiki extracts the patterns and the raw source holds the exhaustive detail.

### Step 3: Read selected pages

Read each selected page fully from `wiki/<type>/<id>.md`. Prioritize:
- `synthesis/` pages first (pre-synthesized answers).
- `entities/` pages for factual queries.
- `concepts/` pages for explanatory queries.
- `sources/` pages for provenance lookups.

**Follow detail pointers (progressive disclosure)**: if the selected page's answer needs reference-level detail (parameters, exact fields), follow the page's trailing detail pointer to its source page / original document instead of guessing or fetching unrelated pages. If a selected page is not self-contained, follow its links to fill the missing context.

### Step 4: Synthesize answer

1. **Cross-reference** information across multiple pages.
2. **Resolve contradictions**: If two pages state conflicting facts, note the contradiction explicitly:
   ```
   > ⚠️ **Contradiction**: [Page A] states X, while [Page B] states Y.
   ```
3. **Compose answer** with inline [[WikiLink]] citations:
   ```
   Ethereum transitioned to Proof of Stake in 2022 (see [[concepts/proof-of-stake]]).
   ```
4. **Confidence**: Indicate overall answer confidence (high / medium / low) based on source quality and agreement.

### Step 5: Source attribution

List all pages consulted at the end of the answer:

```
---
**Sources consulted:**
- [[entities/ethereum]] — Ethereum entity page
- [[concepts/proof-of-stake]] — PoS concept page
- [[sources/ethereum-whitepaper]] — Original whitepaper
```

## Performance Notes

- Pure file approach works well for **0–5,000 pages** (validated in performance-scale-estimation-spike).
- Single query consumes ~1,500–12,000 tokens regardless of total wiki size.
- Beyond that, the bundled BM25 pre-filter ([`search.py`](./scripts/search.py), zero-dependency Python 3) keeps candidate selection within budget — see Step 2.1.

## Output Constraints

- Always cite sources with [[WikiLink]].
- Never fabricate information — if the wiki doesn't contain the answer, say so.
- When confidence is `low`, clearly state the limitation.

---
name: wiki-query
description: Query the LLM Wiki knowledge base — read wiki/index.md for directory, selectively load relevant pages, synthesize answers with [[WikiLink]] citations. Use when user asks questions that may be answered by wiki knowledge, wants to "search the wiki", or needs cross-referenced information from the knowledge base.
argument-hint: "<question>"
---

# Wiki Query — 知识查询

Answer user questions by reading and synthesizing information from the LLM Wiki knowledge base.

## Prerequisites

- The `llm-wiki` repo must be accessible via `$LLM_WIKI_PATH` environment variable.
- Read `plugins/instructions/llm-wiki-schema.instructions.md` for WikiLink syntax and page structure.

## Workflow

### Step 1: Read the index

Read `$LLM_WIKI_PATH/wiki/index.md` to get the full page directory. Parse:
- All pages grouped by type (sources / entities / concepts / synthesis) and tags.
- Page titles and IDs for relevance matching.

### Step 2: Select relevant pages

Based on the user's question, identify candidate pages:

1. **Keyword match**: Match question terms against page titles, tags, and IDs.
2. **Semantic relevance**: Prefer pages whose title/tags overlap with question domain.
3. **Selection budget**: Select at most **10–15 pages** to stay within token budget (target: 1,500–12,000 tokens for page content).

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
- If `wiki/index.md` exceeds ~20K tokens, recommend introducing BM25 search.

## Output Constraints

- Always cite sources with [[WikiLink]].
- Never fabricate information — if the wiki doesn't contain the answer, say so.
- When confidence is `low`, clearly state the limitation.

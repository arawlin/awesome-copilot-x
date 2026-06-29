---
name: wiki-lint
description: Run health checks on the LLM Wiki — detect contradictions, orphan pages, stale content, format violations. Output issues to lint_pending/ for human review, never directly modify pages. Use when user asks to "check wiki health", "lint wiki", "find issues", or audit knowledge base quality.
argument-hint: "[--scope <all|stale|orphans|contradictions|format>]"
---

# Wiki Lint — 健康检查

Audit the LLM Wiki for quality issues. All findings go to `lint_pending/` — **never modify wiki pages directly**.

## Prerequisites

- The `llm-wiki` repo must be accessible via `$LLM_WIKI_PATH` environment variable.
- Read `plugins/instructions/llm-wiki-schema.instructions.md` for page lifecycle and frontmatter rules.
- Read `wiki/.wiki-config.yml` for freshness thresholds.

## Lint Checks

### 1. Staleness Detection (three-layer hybrid)

**Layer 1 — Deterministic pre-screening (no LLM needed):**

| Check | Condition | stale_reason |
|-------|-----------|-------------|
| Review overdue | `current_date > review_by` | `review_due` |
| Source changed | `source_hash` mismatch | `source_changed` |
| Source deleted | `git diff --name-status` shows D | `source_deleted` |
| Schema outdated | `page.schema_version < index.schema_version` | `stale_schema` |

**Layer 2 — Priority scoring:**
Score each stale candidate on: days overdue (×2) + has source_changed (+30) + has source_deleted (+40) + schema gap (+20). Pages scoring > 50 proceed to Layer 3.

**Layer 3 — LLM semantic review:**
For high-priority pages, read the page and its sources. Determine if content is semantically outdated (e.g., "Ethereum uses Proof of Work" when all sources now say PoS). Only suggest — do not rewrite.

### 2. Contradiction Detection (4 types)

| Type | Detection method |
|------|-----------------|
| **Factual contradiction** | Two pages assert mutually exclusive facts (A says X, B says not-X) |
| **Date/number conflict** | Regex: inconsistent dates, percentages, amounts for the same entity |
| **Opinion divergence** | Opinions marked in different pages disagree |
| **Recency conflict** | Newer source contradicts older page content |

Format contradictions as:
```markdown
> ⚠️ **Contradiction**: [[entities/ethereum]] states "Ethereum uses PoW" but [[sources/ethereum-2-0-overview]] states "Ethereum transitioned to PoS in 2022".
```

### 3. Orphan Page Detection

Find pages with zero incoming WikiLinks:
- Scan all wiki pages for `[[<type>/<id>]]` references.
- List pages not referenced by any other page.
- Flag as `lint_pending/orphan-<id>.md`.

### 4. Format Validation

Check every page against schema requirements:
- **Missing required fields**: `type`, `id`, `title`, `created`, `updated`.
- **Invalid status values**: Must be one of `draft | active | stale | contradicted | archived`.
- **Broken WikiLinks**: Links pointing to non-existent pages.
- **Schema version**: Pages with `schema_version` below global version.

## Output

Generate one `lint_pending/*.md` file per issue category with structured findings. Format:

```markdown
---
type: lint-report
category: staleness | contradiction | orphan | format
created: <YYYY-MM-DD>
severity: high | medium | low
affected_pages: [<id1>, <id2>]
---

# Lint Report: <category>

## Findings

### <page-id>
- **Issue**: <description>
- **Recommendation**: <action>
- **Auto-fix available**: yes | no
```

Update `wiki/log.md` with lint operation record.

## Constraints

- **NEVER modify wiki pages directly** — only generate lint reports.
- Report all issues, don't stop at first error.
- For contradictions, include full context from both conflicting pages.
- Respect the `--scope` filter if provided.
